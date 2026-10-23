-- Drop existing schema
DROP DATABASE IF EXISTS METRO_DW;
CREATE DATABASE METRO_DW;
USE METRO_DW;

-- Suppliers Dimension Table
CREATE TABLE Suppliers (
    Supplier_ID INT PRIMARY KEY,
    Supplier_Name VARCHAR(100)
);

-- Stores Dimension Table
CREATE TABLE Stores (
    Store_ID INT PRIMARY KEY,
    Store_Name VARCHAR(100)
);

-- Products Dimension Table
CREATE TABLE Products (
    Product_ID INT PRIMARY KEY,
    Product_Name VARCHAR(100),
    Price DECIMAL(10, 2)
);

-- Customers Dimension Table
CREATE TABLE Customers (
    Customer_ID INT PRIMARY KEY,
    Customer_Name VARCHAR(100),
    Gender VARCHAR(8)
);

-- SalesFact Table (Fact Table)
CREATE TABLE SalesFact (
    Order_ID INT,
    Order_Date DATETIME,
    Product_ID INT,
    Customer_ID INT,
    Store_ID INT,
    Supplier_ID INT,
    Quantity_Ordered INT,
    Time_ID INT,
    Total_Sale DECIMAL(10, 2),
    PRIMARY KEY (Order_ID, Product_ID),
    FOREIGN KEY (Product_ID) REFERENCES Products(Product_ID),
    FOREIGN KEY (Customer_ID) REFERENCES Customers(Customer_ID),
    FOREIGN KEY (Store_ID) REFERENCES Stores(Store_ID),
    FOREIGN KEY (Supplier_ID) REFERENCES Suppliers(Supplier_ID)
);
