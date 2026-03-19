import React, {
  useState,
  useEffect,
  useContext,
  createContext,
  useReducer,
} from 'react';

const ThemeContext = createContext();

function ThemeProvider({ theme, children }) {
  return (
    <ThemeContext.Provider value={{ theme, primary: '#6200ea' }}>
      {children}
    </ThemeContext.Provider>
  );
}

function useCategories() {
  return ['work', 'personal', 'urgent'];
}

function UserCard({ user, onSelect, categories }) {
  console.log('UserCard rendered', user.name);

  const label = categories
    .map((c) => c.toUpperCase())
    .join(' | ');

  return (
    <div onClick={() => onSelect(user)} style={{ marginBottom: 8 }}>
      <strong>{user.name}</strong> — {label}
    </div>
  );
}

const initialState = { count: 0, lastAction: null };

export default function App() {
  const reducer = (state, action) => {
    switch (action.type) {
      case 'increment': return { count: state.count + 1, lastAction: 'increment' };
      case 'reset':     return initialState;
      default:          return state;
    }
  };

  const [state, dispatch] = useReducer(reducer, initialState);
  const [input, setInput] = useState(5);
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState([]);
  const [theme, setTheme] = useState('light');
  const [doubledInput, setDoubledInput] = useState(input * 2);

  useEffect(() => {
    setDoubledInput(input * 2);
  }, [input]);

  const fetchUsers = () => {
    setUsers([
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' },
      { id: 3, name: 'Charlie' },
    ]);
  };

  useEffect(() => {
    fetchUsers();
  });

  const filters = { query, theme };
  useEffect(() => {
    console.log('Filters changed:', filters);
  }, [filters]);

  useEffect(() => {
    const timer = setTimeout(() => {
      console.log('Delayed count:', state.count);
    }, 3000);
  }, []);

  window.addEventListener('resize', () => {
    console.log('resized');
  });

  const handleClick = (user) => {
    console.log('Selected:', user);
  };

  const expensiveResult = Array(10000)
    .fill(0)
    .reduce((acc) => acc + input, 0);

  const filteredUsers = users.filter((u) =>
    u.name.toLowerCase().includes(query.toLowerCase())
  );

  const categories = useCategories();

  function InlineHeader({ title }) {
    return <h2>{title}</h2>;
  }

  return (
    <ThemeProvider theme={theme}>
      <div>
        <InlineHeader title="Performance Challenge" />

        {/* Секция 1: Counter */}
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
          {filteredUsers.map((user, index) => (
            <div key={index}>
              <UserCard
                user={user}
                onSelect={handleClick}
                categories={categories}
              />
            </div>
          ))}
        </section>
        <section>
          <h3>Big List</h3>
          {Array(500)
            .fill(0)
            .map((_, i) => (
              <div>Item {i} — {expensiveResult}</div>
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
