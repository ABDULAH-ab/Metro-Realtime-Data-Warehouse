package com.sample;

import java.util.Scanner;
import java.io.BufferedReader;
import java.io.FileReader;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.*;
import java.io.IOException;

public class LoadAndMeshJoin {

    // // Database URL, Username, and Password
    private static final String URL = "jdbc:mysql://localhost:3306/METRO_DW";
    // private static final String USER = "root"; // Replace with your MySQL username
    // private static final String PASSWORD = "Ps01vI-5rp<p"; // Replace with your MySQL password

    // Master Data SQL Queries
    private static final String CHECK_CUSTOMER_SQL = "SELECT Customer_Name FROM Customers WHERE Customer_ID = ?";
    private static final String CHECK_PRODUCT_SQL = "SELECT Product_ID FROM Products WHERE Product_ID = ?";

    // SalesFact Table Insert SQL Query
    private static final String INSERT_SALESFACT_SQL = "INSERT INTO SalesFact (Order_ID, Order_Date, Product_ID, Customer_ID, Store_ID, Quantity_Ordered, Total_Sale, Time_ID) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

    // Represents a streaming transaction tuple
    static class Transaction {
        int orderId;
        String orderDate;
        int productId;
        int quantityOrdered;
        int customerId;
        int timeId;

        // Enriched fields from Master Data
        int storeId;
        int supplierId;
        double price;
        double totalSale;
        boolean isEnriched = false;

        public Transaction(int orderId, String orderDate, int productId, int quantityOrdered, int customerId, int timeId) {
            this.orderId = orderId;
            this.orderDate = orderDate;
            this.productId = productId;
            this.quantityOrdered = quantityOrdered;
            this.customerId = customerId;
            this.timeId = timeId;
        }
    }

    // Represents Master Data for Product
    static class ProductMD {
        int productId;
        String productName;
        double price;
        int supplierId;
        int storeId;
        public ProductMD(int productId, String productName, double price, int supplierId, int storeId) {
            this.productId = productId;
            this.productName = productName;
            this.price = price;
            this.supplierId = supplierId;
            this.storeId = storeId;
        }
    }

    public static void main(String[] args) {

        Scanner scanner = new Scanner(System.in);
        System.out.print("Enter MySQL Username (press Enter for 'root'): ");
        String user = scanner.nextLine().trim();
        if (user.isEmpty()) user = "root";

        System.out.print("Enter MySQL Password: ");
        String password = scanner.nextLine().trim();

        // Paths to your CSV files
        String customersCsvFile = "customers_data.csv";
        String productsCsvFile = "products_data.csv";
        String transactionCsvFile = "transactions.csv";
        String line;
        String csvSplitBy = ",";

        try (Connection connection = DriverManager.getConnection(URL, user, password)) {
            // Load MySQL JDBC Driver
            Class.forName("com.mysql.cj.jdbc.Driver");

            int partitionSize = 20; // e.g., 20 products per disk buffer partition
            List<List<ProductMD>> diskPartitions = new ArrayList<>();
            // split master data into chunks of size 20

            // Prepare SQL statements for inserting data
            String customerSql = "INSERT INTO Customers (Customer_ID, Customer_Name, Gender) VALUES (?, ?, ?)";
            String supplierSql = "INSERT INTO Suppliers (Supplier_ID, Supplier_Name) VALUES (?, ?)";
            String storeSql = "INSERT INTO Stores (Store_ID, Store_Name) VALUES (?, ?)";
            String productSql = "INSERT INTO Products (Product_ID, Product_Name, Price) VALUES (?, ?, ?)";

            PreparedStatement customerStmt = connection.prepareStatement(customerSql);
            PreparedStatement supplierStmt = connection.prepareStatement(supplierSql);
            PreparedStatement storeStmt = connection.prepareStatement(storeSql);
            PreparedStatement productStmt = connection.prepareStatement(productSql);

            // Prepare statements for checking existing entries in Suppliers and Stores
            String checkSupplierSql = "SELECT COUNT(*) FROM Suppliers WHERE Supplier_ID = ?";
            String checkStoreSql = "SELECT COUNT(*) FROM Stores WHERE Store_ID = ?";

            PreparedStatement checkSupplierStmt = connection.prepareStatement(checkSupplierSql);
            PreparedStatement checkStoreStmt = connection.prepareStatement(checkStoreSql);

            // Process Customers data
            BufferedReader customerReader = new BufferedReader(new FileReader(customersCsvFile));
            customerReader.readLine(); // Skip the header line
            while ((line = customerReader.readLine()) != null) {
                String[] data = line.split(csvSplitBy);
                int customerId = Integer.parseInt(data[0].trim());
                String customerName = data[1].trim();
                String gender = data[2].trim();

                // Insert customer data
                customerStmt.setInt(1, customerId);
                customerStmt.setString(2, customerName);
                customerStmt.setString(3, gender);
                customerStmt.executeUpdate();
                System.out.println("Inserted customer: " + customerName);
            }

            // Process Products data
            BufferedReader productReader = new BufferedReader(new FileReader(productsCsvFile));
            productReader.readLine(); // Skip the header line
            List<ProductMD> allProducts = new ArrayList<>();
            while ((line = productReader.readLine()) != null) {
                String[] data = line.split(csvSplitBy);

                // Parse product data safely
                int productId = 0;
                int supplierId = 0;
                int storeId = 0;
                double price = 0;
                try {
                    productId = Integer.parseInt(data[0].trim());
                    supplierId = Integer.parseInt(data[3].trim());
                    storeId = Integer.parseInt(data[5].trim());
                    price = Double.parseDouble(data[2].trim());
                } catch (NumberFormatException e) {
                    // Skip invalid rows or log the error for debugging
                    System.err.println("Skipping invalid row: " + line);
                    continue; // Skip this row if parsing fails
                }

                String productName = data[1].trim();
                String supplierName = data[4].trim();
                String storeName = data[6].trim();

                allProducts.add(new ProductMD(productId, productName, price, supplierId, storeId));

                // Check if the Supplier already exists
                checkSupplierStmt.setInt(1, supplierId);
                ResultSet rsSupplier = checkSupplierStmt.executeQuery();
                if (rsSupplier.next() && rsSupplier.getInt(1) == 0) {
                    // Insert into Suppliers table if not already present
                    supplierStmt.setInt(1, supplierId);
                    supplierStmt.setString(2, supplierName);
                    supplierStmt.executeUpdate();
                    System.out.println("Inserted supplier: " + supplierName);
                }

                // Check if the Store already exists
                checkStoreStmt.setInt(1, storeId);
                ResultSet rsStore = checkStoreStmt.executeQuery();
                if (rsStore.next() && rsStore.getInt(1) == 0) {
                    // Insert into Stores table if not already present
                    storeStmt.setInt(1, storeId);
                    storeStmt.setString(2, storeName);
                    storeStmt.executeUpdate();
                    System.out.println("Inserted store: " + storeName);
                }

                // Check if Product exists, if not, insert it
                PreparedStatement checkProductStmt = connection.prepareStatement(CHECK_PRODUCT_SQL);
                checkProductStmt.setInt(1, productId);
                ResultSet rsProduct = checkProductStmt.executeQuery();
                if (!rsProduct.next()) {
                    // Product doesn't exist, insert it
                    productStmt.setInt(1, productId);
                    productStmt.setString(2, productName);
                    productStmt.setDouble(3, price);
                    productStmt.executeUpdate();
                    System.out.println("Inserted product: " + productName);
                }
            }

            List<ProductMD> currentPartition = new ArrayList<>();
            for (ProductMD prod : allProducts) {
                currentPartition.add(prod);
                if (currentPartition.size() == partitionSize) {
                    diskPartitions.add(currentPartition);
                    currentPartition = new ArrayList<>();
                }
            }
            if (!currentPartition.isEmpty()) {
                diskPartitions.add(currentPartition);
            }


            // Prepare statement for SalesFact
            String insertSalesFactSql = "INSERT INTO SalesFact (Order_ID, Order_Date, Customer_ID, Product_ID, Store_ID, Supplier_ID, Quantity_Ordered, Time_ID, Total_Sale) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
            PreparedStatement salesFactStmt = connection.prepareStatement(insertSalesFactSql);

            // MESHJOIN for Transactions (Stream)
            int m = diskPartitions.size(); // Number of MD partitions
            int streamChunkSize = 500;     // 'w': tuples read per stream iteration

            // 1. In-memory Hash Table: maps Product_ID -> List of waiting Transactions
            Map<Integer, List<Transaction>> hashTable = new HashMap<>();

            // 2. FIFO Queue of chunks: holds up to m chunks of transactions
            Queue<List<Transaction>> queue = new LinkedList<>();

            BufferedReader transactionReader = new BufferedReader(new FileReader(transactionCsvFile));
            transactionReader.readLine(); // Skip the header line
            int partitionIndex = 0; // Cycles 0 -> (m - 1) -> 0
            boolean hasMoreStream = true;
            int totalInserted = 0;

            System.out.println("Starting MESHJOIN execution...");
            long startTime = System.currentTimeMillis();

            while (hasMoreStream || !queue.isEmpty()) {

                // --- STEP A: Read Stream Chunk (size w) ---
                if (hasMoreStream) {
                    List<Transaction> streamChunk = readNextChunk(transactionReader, streamChunkSize);
                    if (streamChunk.isEmpty()) {
                        hasMoreStream = false;
                    } else {
                        queue.add(streamChunk);
                        for (Transaction tx : streamChunk) {
                            hashTable.computeIfAbsent(tx.productId, k -> new ArrayList<>()).add(tx);
                        }
                    }
                }

                // --- STEP B: Load next MD Partition into Disk Buffer ---
                if (m > 0) {
                    List<ProductMD> diskBuffer = diskPartitions.get(partitionIndex);
                    partitionIndex = (partitionIndex + 1) % m; // Endless cyclic traversal!

                    // --- STEP C: Probe Disk Buffer against Hash Table ---
                    for (ProductMD prod : diskBuffer) {
                        List<Transaction> matches = hashTable.get(prod.productId);
                        if (matches != null) {
                            for (Transaction tx : matches) {
                                if (!tx.isEnriched) {
                                    tx.price = prod.price;
                                    tx.supplierId = prod.supplierId;
                                    tx.storeId = prod.storeId;
                                    tx.totalSale = tx.quantityOrdered * prod.price;
                                    tx.isEnriched = true;
                                }
                            }
                        }
                    }
                }

                // --- STEP D: Evict Oldest Chunk & Load to DW ---
                // If the queue has reached m partitions, the oldest chunk has seen all MD!
                if (queue.size() >= m || (!hasMoreStream && !queue.isEmpty())) {
                    List<Transaction> oldestChunk = queue.poll();
                    
                    // 1. Remove from Hash Table
                    for (Transaction tx : oldestChunk) {
                        List<Transaction> list = hashTable.get(tx.productId);
                        if (list != null) {
                            list.remove(tx);
                            if (list.isEmpty()) hashTable.remove(tx.productId);
                        }
                    }

                    // 2. Batch Insert enriched tuples into SalesFact
                    int batchCount = 0;
                    for (Transaction tx : oldestChunk) {
                        if (tx.isEnriched) {
                            salesFactStmt.setInt(1, tx.orderId);
                            salesFactStmt.setString(2, tx.orderDate);
                            salesFactStmt.setInt(3, tx.customerId);
                            salesFactStmt.setInt(4, tx.productId);
                            salesFactStmt.setInt(5, tx.storeId);
                            salesFactStmt.setInt(6, tx.supplierId);
                            salesFactStmt.setInt(7, tx.quantityOrdered);
                            salesFactStmt.setInt(8, tx.timeId);
                            salesFactStmt.setDouble(9, tx.totalSale);
                            salesFactStmt.addBatch();
                            batchCount++;
                            totalInserted++;
                        }
                    }
                    if (batchCount > 0) {
                        salesFactStmt.executeBatch();
                    }
                }
            }

            long endTime = System.currentTimeMillis();
            System.out.println("MESHJOIN execution completed in " + (endTime - startTime) + " ms!");
            System.out.println("Total enriched transactions loaded into SalesFact: " + totalInserted);
            System.out.println("Data successfully inserted into Customers, Products, Suppliers, Stores, and SalesFact tables.");

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // Helper method to read stream chunks
    private static List<Transaction> readNextChunk(BufferedReader reader, int chunkSize) throws IOException {
        List<Transaction> chunk = new ArrayList<>();
        String line;
        while (chunk.size() < chunkSize && (line = reader.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) continue;
            String[] data = line.split(",");
            try {
                int orderId = Integer.parseInt(data[0].trim());
                String orderDate = data[1].trim();
                int productId = Integer.parseInt(data[2].trim());
                int quantityOrdered = Integer.parseInt(data[3].trim());
                int customerId = Integer.parseInt(data[4].trim());
                int timeId = Integer.parseInt(data[5].trim());
                chunk.add(new Transaction(orderId, orderDate, productId, quantityOrdered, customerId, timeId));
            } catch (Exception e) {
                // Skip header or invalid line
            }
        }
        return chunk;
    }
}