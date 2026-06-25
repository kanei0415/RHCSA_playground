#!/bin/bash

TMP_PASSWORD=$1

echo "===== www-hacker ====="
sshpass -p "$TMP_PASSWORD" ssh -o StrictHostKeyChecking=no www-hacker@192.168.241.159 id
echo "======================"
echo

echo "===== www-user ====="
sshpass -p "$TMP_PASSWORD" ssh -o StrictHostKeyChecking=no www-user@192.168.241.159 id
echo "===================="
echo

echo "===== data-user ====="
sshpass -p "$TMP_PASSWORD" ssh -o StrictHostKeyChecking=no data-user@192.168.241.159 id
echo "====================="
echo

echo "===== db-user ====="
sshpass -p "$TMP_PASSWORD" ssh -o StrictHostKeyChecking=no db-user@192.168.241.159 id
echo "==================="