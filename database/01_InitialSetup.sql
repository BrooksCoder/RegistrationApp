-- SQL Server Database Setup Script for Registration Application
-- This script creates the database, tables, and initial configuration

-- Create the database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'RegistrationAppDb')
BEGIN
    CREATE DATABASE RegistrationAppDb;
END
GO

-- Use the database
USE RegistrationAppDb;
GO

-- Create Items table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Items')
BEGIN
    CREATE TABLE Items (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(200) NOT NULL,
        Description NVARCHAR(1000) NOT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );
END
GO

-- Create indexes for performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Items_CreatedAt')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Items_CreatedAt 
    ON Items(CreatedAt DESC);
END
GO

-- Create stored procedures for common operations
CREATE OR ALTER PROCEDURE sp_GetAllItems
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name, Description, CreatedAt 
    FROM Items 
    ORDER BY CreatedAt DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetItemById
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name, Description, CreatedAt 
    FROM Items 
    WHERE Id = @ItemId;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateItem
    @Name NVARCHAR(200),
    @Description NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Items (Name, Description, CreatedAt)
    VALUES (@Name, @Description, GETUTCDATE());
    
    SELECT SCOPE_IDENTITY() AS Id;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateItem
    @ItemId INT,
    @Name NVARCHAR(200),
    @Description NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Items
    SET Name = @Name, Description = @Description
    WHERE Id = @ItemId;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteItem
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Items
    WHERE Id = @ItemId;
END
GO

-- Add database user for application (Windows Authentication)
-- For SQL Authentication, use:
-- CREATE LOGIN RegistrationAppUser WITH PASSWORD = 'YourSecurePassword!';
-- CREATE USER RegistrationAppUser FOR LOGIN RegistrationAppUser;

-- Grant permissions
-- GRANT SELECT, INSERT, UPDATE, DELETE ON Items TO RegistrationAppUser;
-- GRANT EXECUTE ON sp_GetAllItems TO RegistrationAppUser;
-- GRANT EXECUTE ON sp_GetItemById TO RegistrationAppUser;
-- GRANT EXECUTE ON sp_CreateItem TO RegistrationAppUser;
-- GRANT EXECUTE ON sp_UpdateItem TO RegistrationAppUser;
-- GRANT EXECUTE ON sp_DeleteItem TO RegistrationAppUser;
