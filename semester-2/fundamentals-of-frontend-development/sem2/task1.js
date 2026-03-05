function debounce(fn, delay) {
  let timerId;

  return function (...args) {
    clearTimeout(timerId);
    timerId = setTimeout(() => {
      fn.apply(this, args);
    }, delay);
  };
}

// --- Тест 1 ---
function logValue(value) {
  console.log('Значение:', value);
}

const debouncedLog = debounce(logValue, 500);

debouncedLog('a');
setTimeout(() => debouncedLog('ab'), 100);
setTimeout(() => debouncedLog('abc'), 200);
setTimeout(() => debouncedLog('abcd'), 600);

// --- Тест 2 ---
const obj = {
  name: 'test',
  log: function (value) {
    console.log(this.name, value);
  }
};

const debouncedLogObj = debounce(obj.log, 300);
debouncedLogObj.call(obj, 'hello');

