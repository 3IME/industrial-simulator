@echo off
rem ============================================================
rem  Industrial Simulator - instance ELEVE (tests 2 fenetres)
rem  Rendu OpenGL3/Compatibility : economise la memoire GPU quand
rem  le prof (Vulkan) et l'eleve tournent sur le MEME PC.
rem  Double-cliquez ce fichier, choisissez ELEVE et saisissez
rem  l'IP affichee chez le prof.
rem ============================================================
start "" "%~dp0IndustrialSimulator.exe" --rendering-driver opengl3
