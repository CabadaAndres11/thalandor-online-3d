@echo off
rem Thalandor Online con la red ENet (necesita Tailscale entre casas).
start "" "%~dp0ThalandorOnline.exe" -- --net=enet
