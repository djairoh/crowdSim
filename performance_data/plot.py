import glob
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # nixos is struggling with interactive plots so we do this instead
import matplotlib.pyplot as plt

FILE_PATTERN = "*.log"  


# load data
files = sorted(glob.glob(FILE_PATTERN))
if not files:
    raise SystemExit(f"No files matching {FILE_PATTERN} in the current folder.")

runs = []
for f in files:
    df = pd.read_csv(f, sep=r"\s+", header=None, names=["frame", "fps", "agents"])
    df["run"] = f
    runs.append(df)
data = pd.concat(runs, ignore_index=True)


# per frame mean + stderr (averaged)
frame_stats = data.groupby("frame")[["fps", "agents"]].agg(["mean", "sem"]).fillna(0)

# fps as function of num_agents 
agent_stats = data.groupby("agents")["fps"].agg(["mean", "sem"]).fillna(0)


def plot_band(ax, x, mean, sem, ylabel, color="tab:blue"):
    ax.plot(x, mean, color=color, linewidth=1.5, label="Mean")
    ax.fill_between(x, mean - sem, mean + sem, color=color, alpha=0.25, label="±1 SEM")
    ax.set_ylabel(ylabel)
    ax.grid(alpha=0.3)
    ax.legend()


# plot 1: FPS and num_agents / frame
fig1, axes = plt.subplots(2, 1, sharex=True, figsize=(10, 8))
plot_band(axes[0], frame_stats.index, frame_stats[("fps", "mean")],
          frame_stats[("fps", "sem")], "Frames per second")
plot_band(axes[1], frame_stats.index, frame_stats[("agents", "mean")],
          frame_stats[("agents", "sem")], "Number of agents", color="tab:orange")
axes[1].set_xlabel("Frame")
axes[0].set_title(f"Mean across {len(files)} runs (shaded: ±1 standard error)")
fig1.tight_layout()
fig1.savefig("fps_and_agents_per_frame.png", dpi=150)
plt.close(fig1)

# plot 1: FPS and num_agents / frame
fig2, ax = plt.subplots(figsize=(8, 6))
plot_band(ax, agent_stats.index, agent_stats["mean"], agent_stats["sem"], "Frames per second", color="tab:green")
ax.set_xlabel("Number of agents")
ax.set_title("FPS vs number of agents")
fig2.tight_layout()
fig2.savefig("fps_vs_agents.png", dpi=150)
plt.close(fig2)

print("Saved plots")
