#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-sensitive-files.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no files staged" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sensitive file check passed"* ]]
}

@test "blocks env files" {
  echo "SECRET=abc" >.env
  git add .env

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Sensitive file staged: .env"* ]]
}

@test "blocks key and certificate files" {
  echo "key" >server.key
  echo "cert" >cert.pem
  git add server.key cert.pem

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Sensitive file staged: server.key"* ]]
  [[ "$output" == *"Sensitive file staged: cert.pem"* ]]
}

@test "blocks credential files" {
  echo "{}" >credentials.json
  git add credentials.json

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Sensitive file staged: credentials.json"* ]]
}

@test "blocks auth config files" {
  echo "token" >.npmrc
  git add .npmrc

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Sensitive file staged: .npmrc"* ]]
}

@test "allows files with .example. segment" {
  echo "SECRET=" >.env.example
  echo "placeholder" >cert.example.pem
  git add .env.example cert.example.pem

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sensitive file check passed"* ]]
}

@test "allows files with .sample. and .template. segments" {
  echo "SECRET=" >.env.sample
  echo "SECRET=" >.env.template
  git add .env.sample .env.template

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sensitive file check passed"* ]]
}

@test "blocks when example is not a dot segment" {
  echo "key" >my_example.pem
  echo "key" >example.pem
  git add my_example.pem example.pem

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Sensitive file staged: my_example.pem"* ]]
  [[ "$output" == *"Sensitive file staged: example.pem"* ]]
}

@test "blocks sensitive file in subdirectory" {
  mkdir -p config
  echo "SECRET=abc" >config/.env
  git add config/.env

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Sensitive file staged: config/.env"* ]]
}

@test "shows hint when blocked" {
  echo "SECRET=abc" >.env
  git add .env

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *".example"* ]]
  [[ "$output" == *".sample"* ]]
  [[ "$output" == *".template"* ]]
}

@test "passes with non-sensitive files" {
  echo "code" >app.js
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sensitive file check passed"* ]]
}
