# Get started with BLOC

BLOC is a local 2–4 player tower-building game prototype. Players share one computer and take turns placing pieces. You can also control every player yourself to try it out.

## 1. Get the tools

- Install **Godot 4.7.2**, the version used for this project. Choose the standard version; .NET is not needed.
- Install **Git** if you want to clone the project.

No plugins or external assets are needed.

## 2. Clone the project

Open Terminal (macOS/Linux) or PowerShell (Windows), then run:

```sh
git clone https://github.com/TrentChen27/1450-final-project-BLOC.git
cd 1450-final-project-BLOC
```

If GitHub asks you to sign in, use an account with access to the repository.

You can also open the repository on GitHub, select **Code → Download ZIP**, and extract it instead of using Git. (However, this is will not be able to send you changes and modifications to our project inteadt just creating a local of current version of the game. NOT RECOMMENDED)

## 3. Open it in Godot

1. Launch Godot.
2. In the Project Manager, click **Import**.
3. Select `project.godot` inside the downloaded project folder.
4. Import and open the project. Wait for Godot to finish importing files.

## 4. Run and play

1. Press **F5** or click **Run Project** at the top right. The main scene is already configured.
2. Choose **2, 3, or 4 players**.
3. Click **Begin turn** and follow the instructions at the upper left.
4. Resolve card prompts, place your pieces, then click **End turn** when prompted.

| Key / mouse | Action while placing |
| --- | --- |
| W / A / S / D | Move the piece relative to the camera |
| R / F | Raise / lower the piece |
| Q / E, Z / X, C / V | Rotate the piece on each axis |
| Space | Release the piece when its preview is green |
| Left mouse drag | Orbit the camera |
| Mouse wheel | Zoom over the board |

A red preview means the placement is invalid; read the message at the upper left. After release, wait for the tower to settle before continuing.

Use **Restart** in the sidebar to start a new game. Press **F8** in the editor to stop the running game. On keyboards with media keys, you may need to hold **Fn** with F5 or F8.

## If something does not work

- **The wrong scene opens:** use F5 (Run Project), not F6 (Run Current Scene).
- **The controls do nothing:** click the game view to give it keyboard focus. Movement controls only work while placing a piece.
- **Git says “Repository not found”:** check the URL and that your GitHub account has access.
- **Godot reports script errors:** check that you opened this project's `project.godot` using Godot 4.7.2.

See [README.md](README.md) for the rules, card testing tools, and more controls.
