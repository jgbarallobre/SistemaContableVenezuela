-- ============================================================
-- SISTEMA CONTABLE VENEZUELA - SQL SERVER
-- Multiempresa / Multiusuario / Multi-Moneda
-- Compatible with SQL Server 2019+
-- ============================================================

-- ============================================================
-- 1. ESQUEMA DE SEGURIDAD Y AUTENTICACIÓN
-- ============================================================

-- Tabla de Empresas (Tenants)
CREATE TABLE Companies (
    CompanyId INT IDENTITY(1,1) PRIMARY KEY,
    Code VARCHAR(20) NOT NULL UNIQUE,
    LegalName NVARCHAR(200) NOT NULL,
    CommercialName NVARCHAR(200),
    RIF VARCHAR(20) NOT NULL UNIQUE,
    FiscalAddress NVARCHAR(500) NOT NULL,
    Phone NVARCHAR(50),
    Email NVARCHAR(100),
    Activity NVARCHAR(500),
    FunctionalCurrency VARCHAR(3) NOT NULL DEFAULT 'VES',
    SecondaryCurrency VARCHAR(3) DEFAULT 'USD',
    IVAAliquot DECIMAL(5,2) DEFAULT 16.00,        -- Alícuota general IVA
    ReducedIVAAliquot DECIMAL(5,2) DEFAULT 8.00,  -- Alícuota reducida
    AdditionalIVAAliquot DECIMAL(5,2) DEFAULT 31.50, -- Alícuota adicional
    IGTFAliquot DECIMAL(5,2) DEFAULT 3.00,        -- IGTF (Ley 25/02/2022)
    RetentionPercentage DECIMAL(5,2) DEFAULT 75.00, -- Retención IVA estándar
    ISLRRetentionPercentage DECIMAL(5,2) DEFAULT 2.00, -- Retención ISLR
    Logo VARBINARY(MAX),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    UpdatedAt DATETIME2,
    UpdatedBy INT,
    RowVersion ROWVERSION
);

-- Tabla de Usuarios
CREATE TABLE Users (
    UserId INT IDENTITY(1,1) PRIMARY KEY,
    Username VARCHAR(50) NOT NULL UNIQUE,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Phone NVARCHAR(20),
    IsActive BIT DEFAULT 1,
    IsBlocked BIT DEFAULT 0,
    Is2FAEnabled BIT DEFAULT 0,
    TwoFASecret NVARCHAR(255),
    PasswordChangedAt DATETIME2,
    FailedLoginAttempts INT DEFAULT 0,
    LockedUntil DATETIME2,
    LastLoginAt DATETIME2,
    LastLoginIP VARCHAR(50),
    MustChangePassword BIT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    UpdatedAt DATETIME2,
    UpdatedBy INT,
    RowVersion ROWVERSION
);

-- Tabla de Roles
CREATE TABLE Roles (
    RoleId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT,  -- NULL = rol global del sistema
    Name VARCHAR(50) NOT NULL,
    Description NVARCHAR(255),
    IsSystem BIT DEFAULT 0,  -- Roles del sistema no eliminables
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    UpdatedAt DATETIME2,
    UpdatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE SET NULL
);

-- Tabla de Permisos
CREATE TABLE Permissions (
    PermissionId INT IDENTITY(1,1) PRIMARY KEY,
    Module VARCHAR(50) NOT NULL,
    Action VARCHAR(50) NOT NULL,  -- view, create, edit, delete, approve, export
    Description NVARCHAR(255),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE()
);

-- Relación Roles-Permisos
CREATE TABLE RolePermissions (
    RolePermissionId INT IDENTITY(1,1) PRIMARY KEY,
    RoleId INT NOT NULL,
    PermissionId INT NOT NULL,
    GrantedAt DATETIME2 DEFAULT GETDATE(),
    GrantedBy INT,
    FOREIGN KEY (RoleId) REFERENCES Roles(RoleId) ON DELETE CASCADE,
    FOREIGN KEY (PermissionId) REFERENCES Permissions(PermissionId) ON DELETE CASCADE,
    FOREIGN KEY (GrantedBy) REFERENCES Users(UserId)
);

-- Relación Usuarios-Empresas (Acceso multiempresa)
CREATE TABLE UserCompanies (
    UserCompanyId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    CompanyId INT NOT NULL,
    RoleId INT NOT NULL,
    IsDefault BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (RoleId) REFERENCES Roles(RoleId) ON DELETE NO ACTION,
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(UserId, CompanyId)
);

-- ============================================================
-- 2. ESQUEMA CONTABLE BASE
-- ============================================================

-- Períodos Contables
CREATE TABLE Periods (
    PeriodId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    Year SMALLINT NOT NULL,
    Month TINYINT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'OPEN',  -- OPEN, CLOSED, LOCKED
    ClosingDate DATE,
    ClosedBy INT,
    ClosedAt DATETIME2,
    ClosingNote NVARCHAR(500),
    ReopenedBy INT,
    ReopenedAt DATETIME2,
    ReopeningNote NVARCHAR(500),
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (ClosedBy) REFERENCES Users(UserId),
    FOREIGN KEY (ReopenedBy) REFERENCES Users(UserId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, Year, Month)
);

-- Plan de Cuentas (Estructura Jerárquica)
CREATE TABLE ChartOfAccounts (
    AccountId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    AccountCode VARCHAR(30) NOT NULL,
    AccountName NVARCHAR(200) NOT NULL,
    ParentAccountId INT,  -- Cuenta padre para jerarquía
    AccountLevel TINYINT NOT NULL,  -- 1-6 niveles typical
    Nature VARCHAR(10) NOT NULL,  -- DEBITOR, CREDITOR
    AccountType VARCHAR(20) NOT NULL,  -- ASSET, LIABILITY, EQUITY, INCOME, EXPENSE, OFFBALANCE
    IsMovementsRequired BIT DEFAULT 0,  -- Requiere auxiliares
    RequiresThirdParty BIT DEFAULT 0,
    RequiresCostCenter BIT DEFAULT 0,
    AllowsManualEntry BIT DEFAULT 1,
    Currency VARCHAR(3) DEFAULT 'VES',  -- Moneda de registro
    IsActive BIT DEFAULT 1,
    IsCashFlowItem BIT DEFAULT 0,  -- Para flujo de caja
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    UpdatedAt DATETIME2,
    UpdatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (ParentAccountId) REFERENCES ChartOfAccounts(AccountId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    FOREIGN KEY (UpdatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, AccountCode)
);

-- Terceros (Clientes, Proveedores, Otros)
CREATE TABLE ThirdParties (
    ThirdPartyId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    ThirdPartyType VARCHAR(20) NOT NULL,  -- CUSTOMER, SUPPLIER, EMPLOYEE, OTHER
    RIF VARCHAR(20) NOT NULL,
    LegalName NVARCHAR(200) NOT NULL,
    CommercialName NVARCHAR(200),
    FiscalAddress NVARCHAR(500),
    Phone NVARCHAR(50),
    Email NVARCHAR(100),
    ContactPerson NVARCHAR(200),
    TaxCategory VARCHAR(20),  -- ORDINARY, SPECIAL, EXENT
    IsWithholdingAgent BIT DEFAULT 0,  -- Agente de retención
    IVAApplicable BIT DEFAULT 1,
    ISLRApplicable BIT DEFAULT 1,
    BankAccounts NVARCHAR(MAX),  -- JSON array de cuentas
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    UpdatedAt DATETIME2,
    UpdatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    FOREIGN KEY (UpdatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, RIF)
);

-- Centros de Costo (Opcional)
CREATE TABLE CostCenters (
    CostCenterId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    Code VARCHAR(20) NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    ParentCostCenterId INT,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (ParentCostCenterId) REFERENCES CostCenters(CostCenterId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, Code)
);

-- Bancos
CREATE TABLE Banks (
    BankId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    Code VARCHAR(10) NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, Code)
);

-- Cuentas Bancarias
CREATE TABLE BankAccounts (
    BankAccountId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    BankId INT NOT NULL,
    AccountNumber VARCHAR(30) NOT NULL,
    AccountType VARCHAR(20) NOT NULL,  -- CURRENT, SAVINGS
    Currency VARCHAR(3) NOT NULL,
    AccountName NVARCHAR(100),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (BankId) REFERENCES Banks(BankId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, AccountNumber)
);

-- ============================================================
-- 3. ESQUEMA DE ASIENTOS CONTABLES
-- ============================================================

-- Encabezados de Asientos/Comprobantes
CREATE TABLE JournalEntryHeaders (
    EntryId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    PeriodId INT NOT NULL,
    EntryType VARCHAR(20) NOT NULL,  -- DAILY, INCOME, EXPENSE, ADJUSTMENT, CLOSING
    EntryNumber VARCHAR(20) NOT NULL,
    EntryDate DATE NOT NULL,
    Description NVARCHAR(500) NOT NULL,
    Reference NVARCHAR(100),  -- Referencia externa (factura, etc.)
    Status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',  -- DRAFT, APPROVED, ANNULED
    IsAutomatic BIT DEFAULT 0,
    AutomaticSource VARCHAR(50),  -- Origen si es automático
    ApprovedBy INT,
    ApprovedAt DATETIME2,
    AnnulledBy INT,
    AnnulledAt DATETIME2,
    AnnulmentReason NVARCHAR(500),
    ReversedById INT,
    ReversedByEntryId INT,
    TotalDebit DECIMAL(20,2) DEFAULT 0,
    TotalCredit DECIMAL(20,2) DEFAULT 0,
    Currency VARCHAR(3) DEFAULT 'VES',
    ExchangeRate DECIMAL(20,6) DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    UpdatedAt DATETIME2,
    UpdatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (PeriodId) REFERENCES Periods(PeriodId),
    FOREIGN KEY (ApprovedBy) REFERENCES Users(UserId),
    FOREIGN KEY (AnnulledBy) REFERENCES Users(UserId),
    FOREIGN KEY (ReversedByEntryId) REFERENCES JournalEntryHeaders(EntryId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    FOREIGN KEY (UpdatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, EntryType, EntryNumber)
);

-- Detalle de Asientos (Partidas)
CREATE TABLE JournalEntryLines (
    LineId INT IDENTITY(1,1) PRIMARY KEY,
    EntryId INT NOT NULL,
    LineNumber INT NOT NULL,
    AccountId INT NOT NULL,
    ThirdPartyId INT,
    CostCenterId INT,
    Description NVARCHAR(500),
    Debit DECIMAL(20,2) DEFAULT 0,
    Credit DECIMAL(20,2) DEFAULT 0,
    Currency VARCHAR(3) DEFAULT 'VES',
    ExchangeRate DECIMAL(20,6) DEFAULT 1,
    BaseAmount DECIMAL(20,2) DEFAULT 0,  -- Equivalente en moneda base
    Reference NVARCHAR(100),
    TaxBase DECIMAL(20,2) DEFAULT 0,  -- Base imponible para IVA
    IVAAmount DECIMAL(20,2) DEFAULT 0,
    IGTFAmount DECIMAL(20,2) DEFAULT 0,
    IsIGTFApplicable BIT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (EntryId) REFERENCES JournalEntryHeaders(EntryId) ON DELETE CASCADE,
    FOREIGN KEY (AccountId) REFERENCES ChartOfAccounts(AccountId),
    FOREIGN KEY (ThirdPartyId) REFERENCES ThirdParties(ThirdPartyId),
    FOREIGN KEY (CostCenterId) REFERENCES CostCenters(CostCenterId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId)
);

-- ============================================================
-- 4. ESQUEMA FISCAL - LIBROS DE IVA
-- ============================================================

-- Libro de Compras IVA
CREATE TABLE PurchaseBook (
    PurchaseId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    PeriodId INT NOT NULL,
    TaxDocumentType VARCHAR(20) NOT NULL,  -- INVOICE, IMPORT, DEBIT_NOTE
    DocumentNumber VARCHAR(30) NOT NULL,
    ControlNumber VARCHAR(20),  -- Número de control fiscal
    DocumentDate DATE NOT NULL,
    TaxPeriod DATE NOT NULL,  -- Período fiscal
    SupplierId INT NOT NULL,
    SupplierRIF VARCHAR(20) NOT NULL,
    SupplierName NVARCHAR(200) NOT NULL,
    ImportedAmount DECIMAL(20,2) DEFAULT 0,  -- Monto total incluant IVA
    TaxableAmount DECIMAL(20,2) DEFAULT 0,    -- Base imponible
    IVAAmount DECIMAL(20,2) DEFAULT 0,
    ReducedTaxableAmount DECIMAL(20,2) DEFAULT 0,
    ReducedIVAAmount DECIMAL(20,2) DEFAULT 0,
    AdditionalTaxableAmount DECIMAL(20,2) DEFAULT 0,
    AdditionalIVAAmount DECIMAL(20,2) DEFAULT 0,
    IGTFAmount DECIMAL(20,2) DEFAULT 0,
    IGTFBaseAmount DECIMAL(20,2) DEFAULT 0,
    ISLRRetentionAmount DECIMAL(20,2) DEFAULT 0,
    RetainableIVA DECIMAL(20,2) DEFAULT 0,
    RetainedIVA DECIMAL(20,2) DEFAULT 0,
    RetainedBy NVARCHAR(100),  -- Agente de retención
    AdjustmentAmount DECIMAL(20,2) DEFAULT 0,
    AdjustmentReason NVARCHAR(200),
    IsExempt BIT DEFAULT 0,
    ExemptReason NVARCHAR(200),
    Status VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, REGISTERED, ADJUSTED
    EntryId INT,  -- Asiento contable relacionado
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (PeriodId) REFERENCES Periods(PeriodId),
    FOREIGN KEY (SupplierId) REFERENCES ThirdParties(ThirdPartyId),
    FOREIGN KEY (EntryId) REFERENCES JournalEntryHeaders(EntryId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, DocumentNumber)
);

-- Libro de Ventas IVA
CREATE TABLE SalesBook (
    SaleId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    PeriodId INT NOT NULL,
    TaxDocumentType VARCHAR(20) NOT NULL,  -- INVOICE, CASH_RECEIPT, CREDIT_NOTE, DELIVERY
    DocumentNumber VARCHAR(30) NOT NULL,
    ControlNumber VARCHAR(20),
    DocumentDate DATE NOT NULL,
    TaxPeriod DATE NOT NULL,
    CustomerId INT NOT NULL,
    CustomerRIF VARCHAR(20) NOT NULL,
    CustomerName NVARCHAR(200) NOT NULL,
    SaleType VARCHAR(20) NOT NULL,  -- DOMESTIC, EXPORT, EXEMPT
    TotalAmount DECIMAL(20,2) DEFAULT 0,
    TaxableAmount DECIMAL(20,2) DEFAULT 0,
    IVAAmount DECIMAL(20,2) DEFAULT 0,
    ReducedTaxableAmount DECIMAL(20,2) DEFAULT 0,
    ReducedIVAAmount DECIMAL(20,2) DEFAULT 0,
    AdditionalTaxableAmount DECIMAL(20,2) DEFAULT 0,
    AdditionalIVAAmount DECIMAL(20,2) DEFAULT 0,
    IGTFAmount DECIMAL(20,2) DEFAULT 0,
    ISLRRetentionAmount DECIMAL(20,2) DEFAULT 0,
    ExemptAmount DECIMAL(20,2) DEFAULT 0,
    AdjustmentAmount DECIMAL(20,2) DEFAULT 0,
    AdjustmentReason NVARCHAR(200),
    Status VARCHAR(20) DEFAULT 'PENDING',
    EntryId INT,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    RowVersion ROWVERSION,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (PeriodId) REFERENCES Periods(PeriodId),
    FOREIGN KEY (CustomerId) REFERENCES ThirdParties(ThirdPartyId),
    FOREIGN KEY (EntryId) REFERENCES JournalEntryHeaders(EntryId),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, DocumentNumber)
);

-- ============================================================
-- 5. ESQUEMA DE MONEDAS Y TASAS DE CAMBIO
-- ============================================================

-- Tasas de Cambio
CREATE TABLE ExchangeRates (
    RateId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    FromCurrency VARCHAR(3) NOT NULL,
    ToCurrency VARCHAR(3) NOT NULL,
    RateDate DATE NOT NULL,
    Rate DECIMAL(20,6) NOT NULL,
    RateType VARCHAR(20) DEFAULT 'OFFICIAL',  -- OFFICIAL, BANK, PARALLEL
    Source NVARCHAR(100),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, FromCurrency, ToCurrency, RateDate, RateType)
);

-- Configuración de Monedas por Empresa
CREATE TABLE CurrencyConfigurations (
    ConfigId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    CurrencyCode VARCHAR(3) NOT NULL,
    CurrencyName NVARCHAR(50) NOT NULL,
    Symbol NVARCHAR(5),
    DecimalPlaces TINYINT DEFAULT 2,
    IsBaseCurrency BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    UNIQUE(CompanyId, CurrencyCode)
);

-- ============================================================
-- 6. ESQUEMA DE AUDITORÍA
-- ============================================================

-- Bitácora de Auditoría
CREATE TABLE AuditLog (
    AuditId BIGINT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT,  -- Nullable para acciones del sistema
    UserId INT,
    Action VARCHAR(50) NOT NULL,  -- LOGIN, LOGOUT, CREATE, UPDATE, DELETE, APPROVE, ANNUL, EXPORT
    EntityType VARCHAR(50) NOT NULL,  -- Table or module name
    EntityId INT,
    PreviousValue NVARCHAR(MAX),  -- JSON del estado anterior
    NewValue NVARCHAR(MAX),  -- JSON del nuevo estado
    Reason NVARCHAR(500),
    IPAddress VARCHAR(50),
    UserAgent NVARCHAR(500),
    MachineName NVARCHAR(100),
    SessionId NVARCHAR(100),
    Timestamp DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId),
    FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

-- Índices para auditoría
CREATE INDEX IX_AuditLog_Timestamp ON AuditLog(Timestamp DESC);
CREATE INDEX IX_AuditLog_UserId ON AuditLog(UserId);
CREATE INDEX IX_AuditLog_Entity ON AuditLog(EntityType, EntityId);

-- ============================================================
-- 7. ESQUEMA DE CONFIGURACIÓN DEL SISTEMA
-- ============================================================

-- Configuraciones del Sistema
CREATE TABLE SystemConfigurations (
    ConfigId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT,  -- NULL = configuración global
    ConfigKey VARCHAR(100) NOT NULL,
    ConfigValue NVARCHAR(MAX),
    Description NVARCHAR(255),
    DataType VARCHAR(20) DEFAULT 'STRING',  -- STRING, NUMBER, BOOLEAN, JSON
    IsEncrypted BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    CreatedBy INT,
    UpdatedAt DATETIME2,
    UpdatedBy INT,
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserId),
    FOREIGN KEY (UpdatedBy) REFERENCES Users(UserId),
    UNIQUE(CompanyId, ConfigKey)
);

-- Numeración de Comprobantes
CREATE TABLE DocumentSequences (
    SequenceId INT IDENTITY(1,1) PRIMARY KEY,
    CompanyId INT NOT NULL,
    DocumentType VARCHAR(20) NOT NULL,  -- DAILY, INCOME, EXPENSE, etc.
    Prefix NVARCHAR(10),
    CurrentNumber INT NOT NULL DEFAULT 0,
    MinDigits TINYINT DEFAULT 6,
    Suffix NVARCHAR(10),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (CompanyId) REFERENCES Companies(CompanyId) ON DELETE CASCADE,
    UNIQUE(CompanyId, DocumentType)
);

-- ============================================================
-- 8. ÍNDICES PARA RENDIMIENTO
-- ============================================================

-- Índices para Plan de Cuentas
CREATE INDEX IX_ChartOfAccounts_Company ON ChartOfAccounts(CompanyId);
CREATE INDEX IX_ChartOfAccounts_Parent ON ChartOfAccounts(ParentAccountId);
CREATE INDEX IX_ChartOfAccounts_Code ON ChartOfAccounts(CompanyId, AccountCode);

-- Índices para Asientos
CREATE INDEX IX_JournalHeaders_Company ON JournalEntryHeaders(CompanyId, EntryDate);
CREATE INDEX IX_JournalHeaders_Period ON JournalEntryHeaders(PeriodId);
CREATE INDEX IX_JournalHeaders_Status ON JournalEntryHeaders(Status);
CREATE INDEX IX_JournalLines_Entry ON JournalEntryLines(EntryId);
CREATE INDEX IX_JournalLines_Account ON JournalEntryLines(AccountId);
CREATE INDEX IX_JournalLines_ThirdParty ON JournalEntryLines(ThirdPartyId);

-- Índices para Terceros
CREATE INDEX IX_ThirdParties_Company ON ThirdParties(CompanyId);
CREATE INDEX IX_ThirdParties_RIF ON ThirdParties(CompanyId, RIF);

-- Índices para Períodos
CREATE INDEX IX_Periods_Company ON Periods(CompanyId, Year, Month);

-- Índices para Libros Fiscales
CREATE INDEX IX_PurchaseBook_Period ON PurchaseBook(CompanyId, PeriodId);
CREATE INDEX IX_PurchaseBook_Date ON PurchaseBook(DocumentDate);
CREATE INDEX IX_SalesBook_Period ON SalesBook(CompanyId, PeriodId);
CREATE INDEX IX_SalesBook_Date ON SalesBook(DocumentDate);

-- ============================================================
-- 9. PROCEDIMIENTOS ALMACENADOS - REPORTES CONTABLES
-- ============================================================

-- Balance de Comprobación
CREATE PROCEDURE sp_GetTrialBalance
    @CompanyId INT,
    @PeriodId INT,
    @DateFrom DATE = NULL,
    @DateTo DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE, @EndDate DATE;
    
    SELECT @StartDate = StartDate, @EndDate = EndDate 
    FROM Periods WHERE PeriodId = @PeriodId;
    
    SET @DateFrom = ISNULL(@DateFrom, @StartDate);
    SET @DateTo = ISNULL(@DateTo, @EndDate);
    
    SELECT 
        c.CompanyId,
        c.AccountCode,
        c.AccountName,
        c.Nature,
        c.AccountType,
        c.AccountLevel,
        ISNULL(SUM(d.Debit), 0) - ISNULL(SUM(d.Credit), 0) AS Balance,
        ISNULL(SUM(d.Debit), 0) AS TotalDebit,
        ISNULL(SUM(d.Credit), 0) AS TotalCredit
    FROM ChartOfAccounts c
    LEFT JOIN JournalEntryLines d ON c.AccountId = d.AccountId
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    WHERE c.CompanyId = @CompanyId 
        AND h.EntryDate >= @DateFrom 
        AND h.EntryDate <= @DateTo
        AND h.Status = 'APPROVED'
    GROUP BY c.CompanyId, c.AccountCode, c.AccountName, c.Nature, c.AccountType, c.AccountLevel
    ORDER BY c.AccountCode;
END;

-- Mayor General por Cuenta
CREATE PROCEDURE sp_GetGeneralLedger
    @CompanyId INT,
    @AccountId INT,
    @DateFrom DATE,
    @DateTo DATE,
    @ThirdPartyId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        h.EntryId,
        h.EntryNumber,
        h.EntryDate,
        h.Description,
        d.LineNumber,
        d.Reference,
        ISNULL(t.LegalName, '-') AS ThirdPartyName,
        d.Debit,
        d.Credit,
        (SELECT SUM(Debit) - SUM(Credit) 
         FROM JournalEntryLines 
         WHERE AccountId = @AccountId 
         AND EntryId IN (SELECT EntryId FROM JournalEntryHeaders WHERE EntryDate < @DateFrom)) 
         + SUM(d.Debit) - SUM(d.Credit) OVER (ORDER BY h.EntryDate, d.LineNumber) AS RunningBalance,
        h.Status,
        u.Username AS CreatedBy
    FROM JournalEntryLines d
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    LEFT JOIN ThirdParties t ON d.ThirdPartyId = t.ThirdPartyId
    LEFT JOIN Users u ON h.CreatedBy = u.UserId
    WHERE h.CompanyId = @CompanyId 
        AND d.AccountId = @AccountId
        AND h.EntryDate BETWEEN @DateFrom AND @DateTo
        AND h.Status = 'APPROVED'
        AND (@ThirdPartyId IS NULL OR d.ThirdPartyId = @ThirdPartyId)
    ORDER BY h.EntryDate, h.EntryNumber, d.LineNumber;
END;

-- Estado de Resultados
CREATE PROCEDURE sp_GetIncomeStatement
    @CompanyId INT,
    @PeriodId INT,
    @ShowComparative BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE, @EndDate DATE;
    SELECT @StartDate = StartDate, @EndDate = EndDate 
    FROM Periods WHERE PeriodId = @PeriodId;
    
    -- Cuentas de Ingresos
    SELECT 
        c.AccountCode,
        c.AccountName,
        'INCOME' AS Category,
        -ISNULL(SUM(d.Debit - d.Credit), 0) AS Amount
    FROM ChartOfAccounts c
    LEFT JOIN JournalEntryLines d ON c.AccountId = d.AccountId
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    WHERE c.CompanyId = @CompanyId 
        AND c.AccountType = 'INCOME'
        AND h.EntryDate BETWEEN @StartDate AND @EndDate
        AND h.Status = 'APPROVED'
    GROUP BY c.AccountCode, c.AccountName
    
    UNION ALL
    
    -- Cuentas de Gastos
    SELECT 
        c.AccountCode,
        c.AccountName,
        'EXPENSE' AS Category,
        ISNULL(SUM(d.Debit - d.Credit), 0) AS Amount
    FROM ChartOfAccounts c
    LEFT JOIN JournalEntryLines d ON c.AccountId = d.AccountId
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    WHERE c.CompanyId = @CompanyId 
        AND c.AccountType = 'EXPENSE'
        AND h.EntryDate BETWEEN @StartDate AND @EndDate
        AND h.Status = 'APPROVED'
    GROUP BY c.AccountCode, c.AccountName
    
    ORDER BY AccountCode;
END;

-- Balance General
CREATE PROCEDURE sp_GetBalanceSheet
    @CompanyId INT,
    @PeriodId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EndDate DATE;
    SELECT @EndDate = EndDate FROM Periods WHERE PeriodId = @PeriodId;
    
    -- Activos
    SELECT 
        'ASSET' AS Section,
        c.AccountCode,
        c.AccountName,
        ISNULL(SUM(d.Debit - d.Credit), 0) AS Balance
    FROM ChartOfAccounts c
    LEFT JOIN JournalEntryLines d ON c.AccountId = d.AccountId
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    WHERE c.CompanyId = @CompanyId 
        AND c.AccountType = 'ASSET'
        AND h.EntryDate <= @EndDate
        AND h.Status = 'APPROVED'
    GROUP BY c.AccountCode, c.AccountName
    
    UNION ALL
    
    -- Pasivos
    SELECT 
        'LIABILITY' AS Section,
        c.AccountCode,
        c.AccountName,
        -(ISNULL(SUM(d.Debit - d.Credit), 0)) AS Balance
    FROM ChartOfAccounts c
    LEFT JOIN JournalEntryLines d ON c.AccountId = d.AccountId
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    WHERE c.CompanyId = @CompanyId 
        AND c.AccountType = 'LIABILITY'
        AND h.EntryDate <= @EndDate
        AND h.Status = 'APPROVED'
    GROUP BY c.AccountCode, c.AccountName
    
    UNION ALL
    
    -- Patrimonio
    SELECT 
        'EQUITY' AS Section,
        c.AccountCode,
        c.AccountName,
        -(ISNULL(SUM(d.Debit - d.Credit), 0)) AS Balance
    FROM ChartOfAccounts c
    LEFT JOIN JournalEntryLines d ON c.AccountId = d.AccountId
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    WHERE c.CompanyId = @CompanyId 
        AND c.AccountType = 'EQUITY'
        AND h.EntryDate <= @EndDate
        AND h.Status = 'APPROVED'
    GROUP BY c.AccountCode, c.AccountName
    
    ORDER BY AccountCode;
END;

-- Libro de Compras IVA
CREATE PROCEDURE sp_GetPurchaseBook
    @CompanyId INT,
    @PeriodId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ROW_NUMBER() OVER (ORDER BY DocumentDate) AS RowNumber,
        CONVERT(VARCHAR, DocumentDate, 'dd/MM/yyyy') AS DocumentDate,
        DocumentNumber,
        ControlNumber,
        SupplierRIF,
        SupplierName,
        ImportedAmount,
        TaxableAmount,
        IVAAmount,
        ReducedTaxableAmount,
        ReducedIVAAmount,
        AdditionalTaxableAmount,
        AdditionalIVAAmount,
        IGTFAmount,
        RetainedIVA,
        ISLRRetentionAmount,
        CASE WHEN IsExempt = 1 THEN 'E' ELSE '' END AS ExemptIndicator,
        AdjustmentAmount
    FROM PurchaseBook
    WHERE CompanyId = @CompanyId 
        AND PeriodId = @PeriodId
    ORDER BY DocumentDate;
END;

-- Libro de Ventas IVA
CREATE PROCEDURE sp_GetSalesBook
    @CompanyId INT,
    @PeriodId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ROW_NUMBER() OVER (ORDER BY DocumentDate) AS RowNumber,
        CONVERT(VARCHAR, DocumentDate, 'dd/MM/yyyy') AS DocumentDate,
        DocumentNumber,
        ControlNumber,
        CustomerRIF,
        CustomerName,
        SaleType,
        TotalAmount,
        TaxableAmount,
        IVAAmount,
        ReducedTaxableAmount,
        ReducedIVAAmount,
        AdditionalTaxableAmount,
        AdditionalIVAAmount,
        ExemptAmount,
        ISLRRetentionAmount,
        AdjustmentAmount
    FROM SalesBook
    WHERE CompanyId = @CompanyId 
        AND PeriodId = @PeriodId
    ORDER BY DocumentDate;
END;

-- Reporte de IGTF
CREATE PROCEDURE sp_GetIGTFReport
    @CompanyId INT,
    @PeriodId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        h.EntryNumber,
        h.EntryDate,
        d.Description,
        t.LegalName AS ThirdParty,
        t.RIF,
        d.IGTFBaseAmount AS BaseImponible,
        c.IGTFAliquot AS Alicuota,
        d.IGTFAmount AS IGTF
    FROM JournalEntryLines d
    INNER JOIN JournalEntryHeaders h ON d.EntryId = h.EntryId
    LEFT JOIN ThirdParties t ON d.ThirdPartyId = t.ThirdPartyId
    INNER JOIN Companies c ON h.CompanyId = c.CompanyId
    WHERE h.CompanyId = @CompanyId 
        AND h.PeriodId = @PeriodId
        AND d.IsIGTFApplicable = 1
        AND h.Status = 'APPROVED'
    ORDER BY h.EntryDate;
END;

-- Diario General
CREATE PROCEDURE sp_GetGeneralJournal
    @CompanyId INT,
    @DateFrom DATE,
    @DateTo DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        h.EntryId,
        h.EntryNumber,
        h.EntryType,
        CONVERT(VARCHAR, h.EntryDate, 'dd/MM/yyyy') AS EntryDate,
        h.Description,
        h.Reference,
        h.Status,
        u.Username AS CreatedBy,
        a.AccountCode,
        a.AccountName,
        ISNULL(t.LegalName, '-') AS ThirdPartyName,
        d.Description AS LineDescription,
        d.Debit,
        d.Credit
    FROM JournalEntryHeaders h
    INNER JOIN JournalEntryLines d ON h.EntryId = d.EntryId
    INNER JOIN ChartOfAccounts a ON d.AccountId = a.AccountId
    LEFT JOIN ThirdParties t ON d.ThirdPartyId = t.ThirdPartyId
    LEFT JOIN Users u ON h.CreatedBy = u.UserId
    WHERE h.CompanyId = @CompanyId 
        AND h.EntryDate BETWEEN @DateFrom AND @DateTo
    ORDER BY h.EntryDate, h.EntryNumber, d.LineNumber;
END;

PRINT '===============================================';
PRINT 'Base de datos SQL Server configurada exitosamente';
PRINT 'Total de tablas creadas: 18';
PRINT 'Total de procedimientos almacenados: 9';
PRINT '===============================================';
