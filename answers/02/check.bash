#!/bin/bash

TMP_PASSWORD=$1

echo "===== student1 ====="
sshpass -p "$TMP_PASSWORD" ssh -o StrictHostKeyChecking=no student1@192.168.241.159 id
echo "======================"
echo

echo "===== student2 ====="
sshpass -p "$TMP_PASSWORD" ssh -o StrictHostKeyChecking=no student2@192.168.241.159 id
echo "===================="
echo

echo "===== student3 ====="
sshpass -p "$TMP_PASSWORD" ssh -o StrictHostKeyChecking=no student3@192.168.241.159 id
echo "====================="