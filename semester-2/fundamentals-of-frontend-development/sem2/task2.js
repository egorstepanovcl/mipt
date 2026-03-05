function multiFetch(url, n) {
  const results = [];

  function fetchNext(remaining) {
    if (remaining === 0) {
      return Promise.resolve(results);
    }

    return fetch(url)
      .then(response => response.json())
      .then(data => {
        results.push(data);
        return fetchNext(remaining - 1);
      })
      .catch(error => {
        console.error('Ошибка запроса:', error.message);
        results.push(null);
        return fetchNext(remaining - 1);
      });
  }

  return fetchNext(n);
}

// --- Тест ---
multiFetch('https://jsonplaceholderы.typicode.com/todos/1', 3)
  .then(results => {
    console.log('Results:');
    results.forEach((item, i) => console.log(`  [${i + 1}]`, JSON.stringify(item)));
  })
  .catch(error => {
    console.error('Fetch error:', error);
  });

