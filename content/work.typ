#import "../template.typ": *
= Ход работы

Обновим файл `Dockerfile` (Листинг 1).
#code-block(caption:[Dockerfile])[```Dockerfile
FROM php:8.4-apache
RUN docker-php-ext-install mysqli

COPY index.php /var/www/html/index.php
COPY style.css /var/www/html/style.css
```]


Обновим файл `docker-compose.yml` (Листинг 2).
#code-block(caption:[docker-compose.yml])[```yaml
services:
  web:
    build: .
    ports:
      - "8080:80"
    depends_on:
      db:
        condition: service_healthy
    volumes:
      # Монтируем всю текущую папку в корень веб-сервера
      - ./:/var/www/html

  db:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: appDB
      MYSQL_USER: user
      MYSQL_PASSWORD: password
    volumes:
      - db_data:/var/lib/mysql
      # Автоматическая инициализация БД при первом запуске
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-prootpassword"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  db_data:
```]

Создадим SQL-скрипт инициализации для базы данных. Определим в нём две сущности: `users` и `orders`, со связью "один ко многим" (Листинг 3).
#code-block(caption:[init.sql])[```sql
CREATE DATABASE IF NOT EXISTS appDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'user'@'%' IDENTIFIED BY 'password';
GRANT SELECT, INSERT, UPDATE, DELETE ON appDB.* TO 'user'@'%';
FLUSH PRIVILEGES;

USE appDB;

-- Принудительно указываем кодировку для этого скрипта
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- Сущность 1: Пользователи
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Сущность 2: Заказы (связана с users через user_id)
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Добавляем тестовые данные
INSERT INTO users (name, email, password) VALUES
('Иван Иванов', 'ivan@example.com', 'password123'),
('Петр Петров', 'petr@example.com', 'password456');

INSERT INTO orders (user_id, product_name, amount) VALUES
(1, 'Ноутбук', 50000.00),
(1, 'Мышь', 1500.00),
(2, 'Монитор', 20000.00);
```]

Теперь создадим каталог `/api` в корне проекта. Создадим в нём файлы `db.php` (Листинг 4), `users.php` (Листинг 5) и `orders.php` (Листинг 6). Они будут принимать запросы, взаимодействовать с БД и отдавать JSON.
#code-block(caption:[api/db.php])[```php
<?php
// Данные для подключения к MySQL
$host = 'db';
$username = 'user';
$password = 'password';
$database = 'appDB';

// Создаём подключение к базе данных
$conn = new mysqli($host, $username, $password, $database);

// Проверяем подключение
if ($conn->connect_error) {
    header('Content-Type: application/json; charset=utf-8');
    http_response_code(500);
    echo json_encode([
        'error' => 'Ошибка подключения к базе данных: ' . $conn->connect_error
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// Устанавливаем кодировку UTF-8 для корректной работы с кириллицей
$conn->set_charset('utf8mb4');
```]

#code-block(caption:[api/users.php])[```php
<?php
header('Content-Type: application/json; charset=utf-8');
require_once 'db.php';

/** @var mysqli $conn */
$method = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : null;

#region GET метод
if ($method === 'GET') {
    if ($id !== null) {
        $stmt = $conn->prepare('SELECT id, name, email FROM users WHERE id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();

        if (!$user) {
            http_response_code(404);
            echo json_encode(['error' => 'Пользователь с переданным ID не найден'], JSON_UNESCAPED_UNICODE);
            exit;
        }
        echo json_encode($user, JSON_UNESCAPED_UNICODE);
        exit;
    }

    $result = $conn->query("SELECT id, name, email FROM users ORDER BY id");
    $users = [];
    while ($row = $result->fetch_assoc()) {
        $users[] = $row;
    }
    echo json_encode($users, JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

#region POST метод
if ($method === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);

    if (!isset($data['name']) || trim($data['name']) === '' ||
        !isset($data['email']) || trim($data['email']) === '' ||
        !isset($data['password']) || trim($data['password']) === '') {
        http_response_code(400);
        echo json_encode(['error' => 'Не указаны name, email или password'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $name = trim($data['name']);
    $email = trim($data['email']);
    $password = trim($data['password']);

    $stmt = $conn->prepare('INSERT INTO users (name, email, password) VALUES (?, ?, ?)');
    $stmt->bind_param('sss', $name, $email, $password);

    if (!$stmt->execute()) {
        if ($conn->errno === 1062) {
            http_response_code(409);
            echo json_encode(['error' => 'Пользователь с таким email уже существует'], JSON_UNESCAPED_UNICODE);
            exit;
        }
        http_response_code(500);
        echo json_encode(['error' => 'Ошибка создания пользователя'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    http_response_code(201);
    echo json_encode(['id' => $conn->insert_id, 'name' => $name, 'email' => $email], JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

#region PUT метод
if ($method === 'PUT') {
    $data = json_decode(file_get_contents('php://input'), true);

    if ($id === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Укажите ID пользователя'], JSON_UNESCAPED_UNICODE);
        exit;
    }
    if (!isset($data['name']) || trim($data['name']) === '' ||
        !isset($data['email']) || trim($data['email']) === '' ||
        !isset($data['password']) || trim($data['password']) === '') {
        http_response_code(400);
        echo json_encode(['error' => 'Не указаны name, email или password'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $name = trim($data['name']);
    $email = trim($data['email']);
    $password = trim($data['password']);

    $stmt = $conn->prepare('UPDATE users SET name = ?, email = ?, password = ? WHERE id = ?');
    $stmt->bind_param('sssi', $name, $email, $password, $id);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'Пользователь не найден или данные не изменились'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    echo json_encode(['id' => $id, 'name' => $name, 'email' => $email], JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

#region DELETE метод
if ($method === 'DELETE') {
    if ($id === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Укажите ID пользователя'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $stmt = $conn->prepare('DELETE FROM users WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'Пользователь не найден'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    echo json_encode(['message' => 'Пользователь и связанные данные удалены', 'id' => $id], JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

http_response_code(405);
echo json_encode(['error' => 'Метод не поддерживается'], JSON_UNESCAPED_UNICODE);
```]

#code-block(caption:[api/orders.php])[```php
<?php
header('Content-Type: application/json; charset=utf-8');
require_once 'db.php';

/** @var mysqli $conn */
$method = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : null;

#region GET метод
if ($method === 'GET') {
    if ($id !== null) {
        $stmt = $conn->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $order = $result->fetch_assoc();

        if (!$order) {
            http_response_code(404);
            echo json_encode(['error' => 'Заказ с переданным ID не найден'], JSON_UNESCAPED_UNICODE);
            exit;
        }
        echo json_encode($order, JSON_UNESCAPED_UNICODE);
        exit;
    }

    $result = $conn->query("SELECT * FROM orders ORDER BY id");
    $orders = [];
    while ($row = $result->fetch_assoc()) {
        $orders[] = $row;
    }
    echo json_encode($orders, JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

#region POST метод
if ($method === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);

    if (
        !isset($data['user_id']) ||
        !isset($data['product_name']) || trim($data['product_name']) === '' ||
        !isset($data['amount'])
    ) {
        http_response_code(400);
        echo json_encode(['error' => 'Не указаны user_id, product_name или amount'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $user_id = (int)$data['user_id'];
    $product_name = trim($data['product_name']);
    $amount = $data['amount']; // Можно привести к (int) или (float) в зависимости от типа в БД

    $stmt = $conn->prepare('INSERT INTO orders (user_id, product_name, amount) VALUES (?, ?, ?)');
    $stmt->bind_param('isi', $user_id, $product_name, $amount);
    $stmt->execute();

    $newId = $conn->insert_id;
    http_response_code(201);
    echo json_encode([
        'id' => $newId,
        'user_id' => $user_id,
        'product_name' => $product_name,
        'amount' => $amount
    ], JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

#region PUT метод
if ($method === 'PUT') {
    $data = json_decode(file_get_contents('php://input'), true);

    if ($id === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Укажите ID заказа'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    if (
        !isset($data['user_id']) ||
        !isset($data['product_name']) || trim($data['product_name']) === '' ||
        !isset($data['amount'])
    ) {
        http_response_code(400);
        echo json_encode(['error' => 'Не указаны user_id, product_name или amount'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $user_id = (int)$data['user_id'];
    $product_name = trim($data['product_name']);
    $amount = $data['amount'];

    $stmt = $conn->prepare('UPDATE orders SET user_id = ?, product_name = ?, amount = ? WHERE id = ?');
    $stmt->bind_param('isii', $user_id, $product_name, $amount, $id);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'Заказ не найден или данные не изменились'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    http_response_code(200);
    echo json_encode([
        'id' => $id,
        'user_id' => $user_id,
        'product_name' => $product_name,
        'amount' => $amount
    ], JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

#region DELETE метод
if ($method === 'DELETE') {
    if ($id === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Укажите ID заказа'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $stmt = $conn->prepare('DELETE FROM orders WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'Заказ не найден'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    echo json_encode([
        'message' => 'Заказ удален',
        'id' => $id
    ], JSON_UNESCAPED_UNICODE);
    exit;
}
#endregion

// =========================
// Неподдерживаемый метод
// =========================
http_response_code(405);
echo json_encode(['error' => 'Метод не поддерживается'], JSON_UNESCAPED_UNICODE);
```]

Запустим получившееся приложение с помощью команды `docker compose up -d --build`. Затем протестируем получившийся API при помощи инструмента Curl (Рисунок 1).

#figure(
  image("../assets/ris-1.png"),
  caption: [Получить список всех пользователей (GET)]
)

#figure(
  image("../assets/ris-2.png"),
  caption: [Получить одного пользователя по ID (GET)]
)

#figure(
  image("../assets/ris-3.png"),
  caption: [Создать нового пользователя (POST)]
)

#figure(
  image("../assets/ris-4.png"),
  caption: [Обновить данные пользователя (PUT)]
)

#figure(
  image("../assets/ris-5.png"),
  caption: [Получить список всех заказов (GET)]
)

#figure(
  image("../assets/ris-6.png"),
  caption: [Создать новый заказ для существующего пользователя (POST)]
)

#figure(
  image("../assets/ris-7.png"),
  caption: [Обновить сумму и название заказа (PUT)]
)

#figure(
  image("../assets/ris-8.png"),
  caption: [Удалить заказ (DELETE)]
)

#figure(
  image("../assets/ris-9.png"),
  caption: [Удалить пользователя и проверка каскадного удаления (DELETE)]
)
