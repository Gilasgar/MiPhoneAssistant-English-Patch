@echo off
:: Mi Phone Assistant English Patch - launcher
:: Starts the PowerShell patcher with Administrator rights.
:: Keep this file in the same folder as MiPhoneAssistant-English-Patch.ps1

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0MiPhoneAssistant-English-Patch.ps1\"'"
