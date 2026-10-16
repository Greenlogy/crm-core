import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, Navigate, RouterProvider, useParams } from 'react-router-dom';
import { Layout } from './components/Layout';
import { ApprovalsPage } from './pages/ApprovalsPage';
import { CompanyCheckPage } from './pages/CompanyCheckPage';
import { ContactsPage } from './pages/ContactsPage';
import { DealPage } from './pages/DealPage';
import { OfferPage } from './pages/OfferPage';
import { DealsPage } from './pages/DealsPage';
import { ContractImportPage } from './pages/ContractImportPage';
import { ContractPage } from './pages/ContractPage';
import { ContractsPage } from './pages/ContractsPage';
import { ExceptionsPage } from './pages/ExceptionsPage';
import { NotificationsPage } from './pages/NotificationsPage';
import { CustomerPage } from './pages/CustomerPage';
import { CustomersPage } from './pages/CustomersPage';
import { OomImportPage } from './pages/OomImportPage';
import { OomListPage } from './pages/OomListPage';
import { OomPage } from './pages/OomPage';
import { PersonPage } from './pages/PersonPage';
import { PriceListPage } from './pages/PriceListPage';
import { PriceListsPage } from './pages/PriceListsPage';
import { ProductsPage } from './pages/ProductsPage';
import { ProgramsPage } from './pages/ProgramsPage';
import { SettingsLayout } from './pages/settings/SettingsLayout';
import { MeProvider } from './lib/me';
import { AuditPage } from './pages/settings/AuditPage';
import { CompanyPage } from './pages/settings/CompanyPage';
import { CustomFieldsPage } from './pages/settings/CustomFieldsPage';
import { ImportAliasesPage } from './pages/settings/ImportAliasesPage';
import { JobRunsPage } from './pages/settings/JobRunsPage';
import { LookupsPage } from './pages/settings/LookupsPage';
import { PipelinesPage } from './pages/settings/PipelinesPage';
import { OfferTemplatesPage } from './pages/settings/OfferTemplatesPage';
import { EmailTemplatesPage } from './pages/settings/EmailTemplatesPage';
import { MailboxAccessPage } from './pages/settings/MailboxAccessPage';
import { ProfilePage } from './pages/ProfilePage';
import { ContractInputPage } from './pages/ContractInputPage';
import { ContractMatchingPage } from './pages/ContractMatchingPage';
import { PricingPage } from './pages/settings/PricingPage';
import { TariffMappingPage } from './pages/settings/TariffMappingPage';
import { TeamsPage } from './pages/settings/TeamsPage';
import { UsersPage } from './pages/settings/UsersPage';
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
      { path: 'oom', element: <OomListPage /> },
      { path: 'oom/import', element: <OomImportPage /> },
      { path: 'oom/:id', element: <OomPage /> },
      { path: 'obchody', element: <DealsPage /> },
      { path: 'obchody/:id', element: <DealPage /> },
      { path: 'obchody/:id/podklady', element: <ContractInputPage /> },
      { path: 'zmluvy-k-obchodom', element: <ContractMatchingPage /> },
      { path: 'ponuky/:id', element: <OfferPage /> },
      { path: 'overenie-firmy', element: <CompanyCheckPage /> },
      { path: 'schvalovanie', element: <ApprovalsPage /> },
      { path: 'zmluvy', element: <ContractsPage /> },
      { path: 'zmluvy/import', element: <ContractImportPage /> },
      { path: 'zmluvy/:id', element: <ContractPage /> },
      { path: 'vynimky', element: <ExceptionsPage /> },
      { path: 'upozornenia', element: <NotificationsPage /> },
      { path: 'profil', element: <ProfilePage /> },
      { path: 'profil/:id', element: <ProfilePage /> },
      // Cenníky: pevné adresy pred /cenniky/:id (stránka detailu prijme iba platné ID)
      { path: 'cenniky', element: <PriceListsPage /> },
      { path: 'cenniky/produkty', element: <ProductsPage /> },
      { path: 'cenniky/programy', element: <ProgramsPage /> },
      { path: 'cenniky/:id', element: <PriceListPage /> },
      {
        path: 'nastavenia',
        element: <SettingsLayout />,
        children: [
          { index: true, element: <Navigate to="pouzivatelia" replace /> },
          { path: 'spolocnost', element: <CompanyPage /> },
          { path: 'pouzivatelia', element: <UsersPage /> },
          { path: 'timy', element: <TeamsPage /> },
          { path: 'ciselniky', element: <LookupsPage /> },
          { path: 'parovanie-sadzieb', element: <TariffMappingPage /> },
          { path: 'cenove-parametre', element: <PricingPage /> },
          { path: 'sablony-ponuk', element: <OfferTemplatesPage /> },
          { path: 'sablony-emailov', element: <EmailTemplatesPage /> },
          { path: 'preklady-importov', element: <ImportAliasesPage /> },
          { path: 'vlastne-polia', element: <CustomFieldsPage /> },
          { path: 'pipelines', element: <PipelinesPage /> },
          { path: 'audit', element: <AuditPage /> },
          { path: 'citanie-schranok', element: <MailboxAccessPage /> },
          { path: 'nocny-beh', element: <JobRunsPage /> },
        ],
      },
      { path: '*', element: <Navigate to="/zakaznici" replace /> },
    ],
  },
]);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <MeProvider>
      <RouterProvider router={router} />
    </MeProvider>
  </StrictMode>,
);
