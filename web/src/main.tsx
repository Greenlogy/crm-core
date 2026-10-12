import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, Navigate, RouterProvider, useParams } from 'react-router-dom';
import { Layout } from './components/Layout';
import { ContactsPage } from './pages/ContactsPage';
import { ContractPage } from './pages/ContractPage';
import { CustomerPage } from './pages/CustomerPage';
import { CustomersPage } from './pages/CustomersPage';
import { OomPage } from './pages/OomPage';
import { PersonPage } from './pages/PersonPage';
import './styles/tokens.css';
import './styles/app.css';

// Staré adresy kariet domácnosti z prvej verzie prototypu.
function OldPersonRedirect() {
  const { id = '' } = useParams();
  return <Navigate to={`/osoby/${id}`} replace />;
}

const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { index: true, element: <Navigate to="/zakaznici" replace /> },
      { path: 'zakaznici', element: <CustomersPage /> },
      { path: 'leady', element: <CustomersPage key="leady" leads /> },
      { path: 'kontakty', element: <ContactsPage /> },
      { path: 'firmy/:id', element: <CustomerPage /> },
      { path: 'osoby/:id', element: <PersonPage /> },
      { path: 'domacnosti/:id', element: <OldPersonRedirect /> },
      { path: 'oom/:id', element: <OomPage /> },
      { path: 'zmluvy/:id', element: <ContractPage /> },
      { path: '*', element: <Navigate to="/zakaznici" replace /> },
    ],
  },
]);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <RouterProvider router={router} />
  </StrictMode>,
);
