# Задача 1

Реализуйте функцию `debounce`.

## Рекомендации

- Проверьте, что функция вызывается не сразу, а только после паузы
- Убедитесь, что при повторных вызовах таймер сбрасывается
- Проверьте, что контекст (`this`) и аргументы передаются корректно

## Тестовый код

```js
// Функция для теста
function logValue(value) {
  console.log('Значение:', value);
}

// Создаём debounced-функцию
const debouncedLog = debounce(logValue, 500);

// Имитация вызовов - например, ввод в инпут
debouncedLog('a');
setTimeout(() => debouncedLog('ab'), 100);
setTimeout(() => debouncedLog('abc'), 200);
setTimeout(() => debouncedLog('abcd'), 600);
// Вывод: только 'abcd' через 500 мс после последнего вызова

// Проверка контекста и аргументов
const obj = {
  name: 'test',
  log: function (value) {
    console.log(this.name, value);
  }
};

const debouncedLogObj = debounce(obj.log, 300);
debouncedLogObj.call(obj, 'hello');
```

# Задача 2

Реализуйте функцию `multiFetch(url, n)`, которая делает `fetch`-запрос к переданному URL ровно `n` раз и возвращает массив результатов (ответы от сервера) через промис.

Запросы должны выполняться **последовательно**: новый `fetch` запускается только после завершения предыдущего.

## Требования

- Используйте исключительно **Promise API**, не применяя `async/await`
- Продумайте обработку ошибок: если один из запросов завершился с ошибкой, результат должен содержать либо ошибку, либо `null` для этого конкретного запроса
- Проверьте, что функция работает при разных значениях `n`
- Код должен быть чистым и самодокументирующимся

## Шаблон функции

```js
function multiFetch(url, n) {
  // Реализация через Promise API
  // Функция возвращает промис, который резолвится массивом ответов
}
```

## Пример тестового кода

```js
// Тестовый сервер: https://jsonplaceholder.typicode.com/todos/1
multiFetch('https://jsonplaceholder.typicode.com/todos/1', 3)
  .then(results => {
    console.log('Results:', results);
    // Ожидается: массив из 3 объектов-ответов
  })
  .catch(error => {
    console.error('Fetch error:', error);
  });
```

