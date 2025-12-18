# Duplicate File Finder and Cleaner

## Description
Duplicate File Finder and Cleaner is a command-line based project developed using **Bash scripting**.  
It is designed to find **duplicate files**, **empty files**, and **empty folders** in a given directory.  
The program checks file content using **MD5 hash**, so files with the same data are detected even if their names are different.

This project works on **Linux and macOS** systems.

---

## Features
- Scan directories and sub-directories  
- Detect duplicate files using MD5 hashing  
- Identify empty files and empty folders  
- Display duplicate files in clear groups  
- Safe cleaning with user confirmation  
- Simple and readable terminal output  

---

## Tools and Commands Used
- Bash Shell  
- `find` – for scanning files and folders  
- `stat` – for checking file size  
- `md5sum` – for generating hash values  
- `sort` – for organizing data  
- Bash loops, arrays, and conditional statements  

---

## How to Run the Project

### Step 1: Open Terminal
Navigate to the folder where the script file is saved.
```bash
cd /path/to/your/script
