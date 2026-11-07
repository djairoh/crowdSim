<br/>
<div align="center">
  <p align="center">
    <h1 align="center">HiDAC Godot</h1>
    <p align="center">This repository contains a reimplementation of the HiDAC crowd simulation model in the Godot game engine.</p>
</div>


## Table of Contents

* [About the Project](#about) 
* [Dependencies](#dependencies)
* [Usage](#usage)


## About
This repository contains the Godot code which reimplements the HiDAC<sup>[1](#footnote1)</sup> crowd simulation model in Godot.

Ths project was developed as part of the Modelling and Simulation course at the RUG.


## Dependencies
Aside from the Python code used to plot performance data in the `feat/performance` (dependencies for which are listed in the README in that branch) this project only relies on Godot 4.8 to run.
Realistically any Godot 4.* version should suffice. 

## Usage

Simply open the godot engine and import the Project through the `project.godot` file in the repository root.

Run the project by pressing F5.
Inside the simulation there are a few (non intuitive) keybinds. These are outlined here:
| Key             | Action                   |
|-----------------|--------------------------|
| Space           | Toggle simulation pause  |
| R               | Reset simulation         |
| D               | Toggle debug information |
| Escape          | Level select             |
| CapsLock        | Level select             |
| MouseWheel      | Camera zoom              |
| MiddleMouseDrag | Camera position          |
----------------------------------------------



<a name="footnote1">1</a>: Allbeck, Jan M., Nuria Pelechano, and Norman I. Badler. "Controlling individual agents in high-density crowd simulation." Proceedings of the 2007 ACM SIGGRAPH/Eurographics symposium on Computer animation. No. 210. 2007.
