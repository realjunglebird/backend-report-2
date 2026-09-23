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
USE appDB;

-- Сущность 1: Пользователи
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

-- Сущность 2: Заказы (связана с users через user_id)
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Добавляем тестовые данные
INSERT INTO users (name, email, password) VALUES
('Иван Иванов', 'ivan@example.com', 'password123'),
('Петр Петров', 'petr@example.com', 'password456');

INSERT INTO orders (user_id, product_name, amount) VALUES
(1, 'Ноутбук', 50000.00),
(1, 'Мышь', 1500.00),
(2, 'Монитор', 20000.00);
```]

Теперь создадим каталог `/api` в корне проекта. Создадим в нём файлы `users.php` (Листинг 4) и `orders.php` (Листинг 5). Они будут принимать запросы, взаимодействовать с БД и отдавать JSON.
#code-block(caption:[api/users.php])[```php
<?php
// Устанавливаем заголовок ответа в формате JSON
header('Content-Type: application/json; charset=utf-8');

// Настройки подключения к БД (должны совпадать с docker-compose.yml)
$host = 'db';
$db   = 'appDB';
$user = 'user';
$pass = 'password';
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (\PDOException $e) {
    http_response_code(500);
    echo json_encode(["error" => "Ошибка подключения к БД: " . $e->getMessage()]);
    exit;
}

// Определяем метод HTTP-запроса и читаем тело запроса (для POST/PUT)
$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        // Получение пользователя по ID или списка всех пользователей
        if (isset($_GET['id'])) {
            $stmt = $pdo->prepare('SELECT id, name, email FROM users WHERE id = ?');
            $stmt->execute([$_GET['id']]);
            $userData = $stmt->fetch();
            // Примечание: пароль намеренно не возвращается в GET-запросах в целях безопасности
            echo $userData ? json_encode($userData) : json_encode(["error" => "Пользователь не найден"]);
        } else {
            $stmt = $pdo->query('SELECT id, name, email FROM users');
            echo json_encode($stmt->fetchAll());
        }
        break;

    case 'POST':
        // Создание нового пользователя
        if (!isset($input['name'], $input['email'], $input['password'])) {
            http_response_code(400);
            echo json_encode(["error" => "Необходимо указать поля: name, email, password"]);
            break;
        }

        $stmt = $pdo->prepare('INSERT INTO users (name, email, password) VALUES (?, ?, ?)');
        try {
            $stmt->execute([$input['name'], $input['email'], $input['password']]);
            http_response_code(201); // 201 Created
            echo json_encode(["message" => "Пользователь успешно создан", "id" => $pdo->lastInsertId()]);
        } catch (PDOException $e) {
            http_response_code(409); // 409 Conflict (например, если email уже занят)
            echo json_encode(["error" => "Ошибка создания: " . $e->getMessage()]);
        }
        break;

    case 'PUT':
        // Обновление данных пользователя
        if (isset($_GET['id'])) {
            if (!isset($input['name'], $input['email'], $input['password'])) {
                http_response_code(400);
                echo json_encode(["error" => "Необходимо указать поля: name, email, password"]);
                break;
            }
            $stmt = $pdo->prepare('UPDATE users SET name = ?, email = ?, password = ? WHERE id = ?');
            $stmt->execute([$input['name'], $input['email'], $input['password'], $_GET['id']]);
            echo json_encode(["message" => "Данные пользователя обновлены"]);
        } else {
            http_response_code(400);
            echo json_encode(["error" => "Не указан ID пользователя для обновления"]);
        }
        break;

    case 'DELETE':
        // Удаление пользователя
        if (isset($_GET['id'])) {
            $stmt = $pdo->prepare('DELETE FROM users WHERE id = ?');
            $stmt->execute([$_GET['id']]);
            // Благодаря ON DELETE CASCADE в БД, заказы этого пользователя тоже удалятся
            echo json_encode(["message" => "Пользователь и связанные данные удалены"]);
        } else {
            http_response_code(400);
            echo json_encode(["error" => "Не указан ID пользователя для удаления"]);
        }
        break;

    default:
        http_response_code(405); // 405 Method Not Allowed
        echo json_encode(["error" => "Метод не поддерживается"]);
        break;
}
```]

#code-block(caption:[api/orders.php])[```php
<?php
header('Content-Type: application/json; charset=utf-8');

// Настройки БД
$host = 'db';
$db   = 'appDB';
$user = 'user';
$pass = 'password';
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (\PDOException $e) {
    http_response_code(500);
    echo json_encode(["error" => "Ошибка подключения к БД: " . $e->getMessage()]);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        if (isset($_GET['id'])) {
            $stmt = $pdo->prepare('SELECT * FROM orders WHERE id = ?');
            $stmt->execute([$_GET['id']]);
            $order = $stmt->fetch();
            echo $order ? json_encode($order) : json_encode(["error" => "Заказ не найден"]);
        } else {
            $stmt = $pdo->query('SELECT * FROM orders');
            echo json_encode($stmt->fetchAll());
        }
        break;

    case 'POST':
        $stmt = $pdo->prepare('INSERT INTO orders (user_id, product_name, amount) VALUES (?, ?, ?)');
        $stmt->execute([$input['user_id'], $input['product_name'], $input['amount']]);
        http_response_code(201);
        echo json_encode(["message" => "Заказ создан", "id" => $pdo->lastInsertId()]);
        break;

    case 'PUT':
        if (isset($_GET['id'])) {
            $stmt = $pdo->prepare('UPDATE orders SET user_id = ?, product_name = ?, amount = ? WHERE id = ?');
            $stmt->execute([$input['user_id'], $input['product_name'], $input['amount'], $_GET['id']]);
            echo json_encode(["message" => "Заказ обновлен"]);
        } else {
            http_response_code(400);
            echo json_encode(["error" => "Не указан ID заказа"]);
        }
        break;

    case 'DELETE':
        if (isset($_GET['id'])) {
            $stmt = $pdo->prepare('DELETE FROM orders WHERE id = ?');
            $stmt->execute([$_GET['id']]);
            echo json_encode(["message" => "Заказ удален"]);
        } else {
            http_response_code(400);
            echo json_encode(["error" => "Не указан ID заказа"]);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(["error" => "Метод не поддерживается"]);
        break;
}
```]

Запустим получившееся приложение с помощью команды `docker compose up -d --build`. Затем протестируем получившийся API при помощи инструмента Curl (Рисунок 1).



// #figure(
//   image("../assets/ris-1.PNG"),
//   caption: [Получившаяся в результате практической работы страница]
// )
