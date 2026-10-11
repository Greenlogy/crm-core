import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, Navigate, RouterProvider } from 'react-router-dom';
import { Layout } from './components/Layout';
import { ContractPage } from './pages/ContractPage';
import { CustomerPage } from './pages/CustomerPage';
import { CustomersPage } from './pages/CustomersPage';
import { OomPage } from './pages/OomPage';
import './styles/tokens.css';
import './styles/app.css';

const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { index: true, element: <Navigate to="/zakaznici" replace /> },
      { path: 'zakaznici', element: <CustomersPage /> },
      { path: 'firmy/:id', element: <CustomerPage kind="company" /> },
      { path: 'domacnosti/:id', element: <CustomerPage kind="person" /> },
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
