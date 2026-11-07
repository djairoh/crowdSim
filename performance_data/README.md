# Performance data

each file in this folder contains performance measuring data for one individual run.
The filename indicates the used scenario (i.e. the performance_level).

Each file consists of a number of *n* lines, each in the format:
```
[frame] [frames per second] [number of agents]
```

# Plotting

The data was plotted using the script in this folder (`plot.py`), for which the dependencies are listed in `requirements.txt` (but really they're the standard matplotlib, numpy, and pandas libraries).
