import React, {
  useState,
  useEffect,
  useContext,
  createContext,
  useReducer,
  useMemo,
  useCallback,
  memo
} from 'react';

const ThemeContext = createContext();

function ThemeProvider({ theme, children }) {
  return (
    <ThemeContext.Provider value={{ theme, primary: '#6200ea' }}>
      {children}
    </ThemeContext.Provider>
  );
}

// Убрал префикс use- (поскольку это не хук) и вынес константу за пределы компонента
const CATEGORIES = ['work', 'personal', 'urgent'];

// Обернул компонент в React.memo, чтобы он не рендерился вхолостую, если пропсы не изменились
const UserCard = memo(({ user, onSelect, categories }) => {
  console.log('UserCard rendered', user.name);

  const label = categories.map((c) => c.toUpperCase()).join(' | ');

  return (
    <div onClick={() => onSelect(user)} style={{ marginBottom: 8 }}>
      <strong>{user.name}</strong> — {label}
    </div>
  );
});

const initialState = { count: 0, lastAction: null };

// Вынес reducer за пределы App, чтобы функция не пересоздавалась при каждом рендере
const reducer = (state, action) => {
  switch (action.type) {
    case 'increment': return { count: state.count + 1, lastAction: 'increment' };
    case 'reset':     return initialState;
    default:          return state;
  }
};

// Вынес этот компонент за пределы App, чтобы предотвратить его полное пересоздание (unmount/mount) при каждом рендере родителя
function InlineHeader({ title }) {
  return <h2>{title}</h2>;
}

export default function App() {
  const [state, dispatch] = useReducer(reducer, initialState);
  const [input, setInput] = useState(5);
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState([]);
  const [theme, setTheme] = useState('light');

  // Убрал лишние useState и useEffect, так как производное состояние лучше и быстрее вычислять синхронно
  const doubledInput = input * 2;

  // Добавил пустой массив зависимостей [], чтобы fetchUsers вызывался один раз и не создавал бесконечный цикл
  useEffect(() => {
    setUsers([
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' },
      { id: 3, name: 'Charlie' },
    ]);
  }, []);

  // Заменил объект filters в зависимостях на примитивы (query, theme), чтобы избежать ложных срабатываний эффекта из-за пересоздания объекта
  useEffect(() => {
    console.log('Filters changed:', { query, theme });
  }, [query, theme]);

  // Добавил функцию отписки (clearTimeout) и указал правильную зависимость state.count, чтобы не плодить таймеры
  useEffect(() => {
    const timer = setTimeout(() => {
      console.log('Delayed count:', state.count);
    }, 3000);
    return () => clearTimeout(timer);
  }, [state.count]);

  // Обернул подписку на глобальный eventListener в useEffect и добавил функцию отписки, чтобы избежать жесткой утечки памяти
  useEffect(() => {
    const handleResize = () => console.log('resized');
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Мемоизировал эту функцию с помощью useCallback, чтобы она не пересоздавалась и не ломала мемоизацию в компоненте UserCard
  const handleClick = useCallback((user) => {
    console.log('Selected:', user);
  }, []);

  // Обернул тяжелые синхронные вычисления в useMemo, чтобы они пересчитывались только при изменении input
  const expensiveResult = useMemo(() => {
    return Array(10000)
      .fill(0)
      .reduce((acc) => acc + input, 0);
  }, [input]);

  // Вынес фильтрацию списка в useMemo, чтобы не фильтровать пользователей заново при каждом изменении других стейтов (например, при вводе цифр или смене темы)
  const filteredUsers = useMemo(() => 
    users.filter((u) => u.name.toLowerCase().includes(query.toLowerCase())),
  [users, query]);

  return (
    <ThemeProvider theme={theme}>
      <div>
        <InlineHeader title="Performance Challenge" />

        <section>
          <h3>Counter (useReducer)</h3>
          <p>Count: {state.count} | Last: {state.lastAction}</p>
          <button onClick={() => dispatch({ type: 'increment' })}>+1</button>
          <button onClick={() => dispatch({ type: 'reset' })}>Reset</button>
        </section>
        
        <section>
          <h3>Expensive Calculation</h3>
          <input
            type="number"
            value={input}
            onChange={(e) => setInput(Number(e.target.value))}
          />
          <div>Result: {expensiveResult}</div>
          <div>Doubled input: {doubledInput}</div>
        </section>

        <section>
          <h3>User Search</h3>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search..."
          />
          {/* Использовал стабильный уникальный user.id в качестве key вместо индекса массива */}
          {filteredUsers.map((user) => (
            <UserCard
              key={user.id}
              user={user}
              onSelect={handleClick}
              categories={CATEGORIES}
            />
          ))}
        </section>

        <section>
          <h3>Big List</h3>
          {/* Использовал Array.from для создания массива и добавил уникальный строковый key для каждого элемента */}
          {Array.from({ length: 500 }).map((_, i) => (
            <div key={`big-list-${i}`}>Item {i} — {expensiveResult}</div>
          ))}
        </section>

        <section>
          <h3>Theme</h3>
          <button onClick={() => setTheme(t => t === 'light' ? 'dark' : 'light')}>
            Toggle ({theme})
          </button>
          <ThemedBox />
        </section>
      </div>
    </ThemeProvider>
  );
}

function ThemedBox() {
  const { theme } = useContext(ThemeContext);
  console.log('ThemedBox rendered');
  return (
    <div style={{ background: theme === 'dark' ? '#333' : '#eee', padding: 16 }}>
      Current theme: {theme}
    </div>
  );
}
