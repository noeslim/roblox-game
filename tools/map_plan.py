"""Draws the city plan (docs/img/map_plan.png). Units: studs. x = east, z = south (down on the image)."""
import matplotlib

matplotlib.use("Agg")
import matplotlib.patches as patches
import matplotlib.pyplot as plt

CELL = 520
ROAD = 40
HALF = 1.5 * CELL + ROAD

districts = [
    # (col, row, name, color, subtitle)
    (0, 0, "RICH HILLS", "#3B3355", "mansions · VIP clients"),
    (1, 0, "CHINATOWN", "#5C2433", "night market · neon alleys"),
    (2, 0, "THE DOCKS", "#1F3A4F", "legal supplier · smuggling"),
    (0, 1, "THE BLOCKS", "#2E4A36", "trap houses (player bases)"),
    (1, 1, "DOWNTOWN", "#3A3A46", "plaza · police HQ · bank"),
    (2, 1, "INDUSTRIAL", "#4A3F2E", "factories · rail yard"),
    (0, 2, "THE BLOCKS II", "#2E4A36", "trap houses (player bases)"),
    (1, 2, "STRIP", "#3F3048", "shops · gas station · bar"),
    (2, 2, "WAR ZONE", "#5A2020", "gang war · 5 control points"),
]

fig, ax = plt.subplots(figsize=(11, 11), dpi=110)
ax.set_facecolor("#0E0D16")
fig.patch.set_facecolor("#0E0D16")

# ring road + avenues
ax.add_patch(patches.Rectangle((-HALF - ROAD, -HALF - ROAD), 2 * (HALF + ROAD), 2 * (HALF + ROAD), color="#1B1B22"))
for col, row, name, color, sub in districts:
    x = -HALF + col * (CELL + ROAD) + ROAD / 2
    z = -HALF + row * (CELL + ROAD) + ROAD / 2
    ax.add_patch(patches.Rectangle((x, z), CELL, CELL, color=color, alpha=0.95))
    ax.text(x + CELL / 2, z + 22, name, ha="center", va="center", color="white", fontsize=14, weight="bold",
            bbox=dict(boxstyle="round,pad=0.2", fc="#0E0D16", ec="none", alpha=0.6))
    ax.text(x + CELL / 2, z + CELL - 14, sub, ha="center", va="center", color="#D8D0F0", fontsize=9)

# water on the docks side
ax.add_patch(patches.Rectangle((HALF + ROAD, -HALF - ROAD), 160, CELL + 2 * ROAD, color="#12324A"))
ax.text(HALF + ROAD + 80, -HALF + CELL / 2, "SEA", color="#8FC3E6", ha="center", rotation=90, fontsize=12)

# trap houses: 3 x 3 per Blocks district (18 total)
for row in (1, 2):
    bx = -HALF + ROAD / 2
    bz = -HALF + row * (CELL + ROAD) + ROAD / 2
    for i in range(3):
        for j in range(3):
            hx = bx + 40 + i * 160
            hz = bz + 60 + j * 150
            ax.add_patch(patches.Rectangle((hx, hz), 110, 110, facecolor="#58B368", edgecolor="#C8FFD8", lw=1))
            ax.text(hx + 55, hz + 55, "house", color="#0E2A14", ha="center", va="center", fontsize=7, weight="bold")

# war zone control points and gang spawns
wx = -HALF + 2 * (CELL + ROAD) + ROAD / 2
wz = -HALF + 2 * (CELL + ROAD) + ROAD / 2
for label, (px, pz) in zip("ABCDE", [(0.22, 0.3), (0.62, 0.3), (0.45, 0.55), (0.3, 0.8), (0.75, 0.72)]):
    ax.add_patch(patches.Circle((wx + px * CELL, wz + pz * CELL), 34, color="#FFB020"))
    ax.text(wx + px * CELL, wz + pz * CELL, label, ha="center", va="center", weight="bold", color="#1A1A1A")
ax.add_patch(patches.Rectangle((wx + CELL - 90, wz + 20), 70, 110, color="#C0392B"))
ax.text(wx + CELL - 55, wz + 75, "RED\nspawn", ha="center", va="center", color="white", fontsize=8, weight="bold")
ax.add_patch(patches.Rectangle((wx + 20, wz + CELL - 90), 110, 70, color="#2E6FD8"))
ax.text(wx + 75, wz + CELL - 55, "BLUE\nspawn", ha="center", va="center", color="white", fontsize=8, weight="bold")

# points of interest
dx = -HALF + (CELL + ROAD) + ROAD / 2
dz = -HALF + (CELL + ROAD) + ROAD / 2
pois = [
    (dx + 260, dz + 300, "Plaza\n(spawn)", "#FFFFFF"),
    (dx + 90, dz + 80, "Police HQ", "#3FA9F5"),
    (dx + 440, dz + 90, "Bank", "#39FF88"),
    (dx + 260, -HALF + ROAD / 2 + 430, "Black market\nalley (night)", "#FF3FA4"),
    (HALF - 250, -HALF + ROAD / 2 + 120, "Supplier\nwarehouse", "#FFB020"),
    (HALF - 120, -HALF + ROAD / 2 + 400, "Smuggling\npier", "#FFB020"),
    (dx + 260, -HALF + 2 * (CELL + ROAD) + 260, "Gas station\n& bar", "#B45CFF"),
    (-HALF + 260, -HALF + 280, "VIP mansions", "#FFD27A"),
]
for x, z, label, color in pois:
    ax.add_patch(patches.Circle((x, z), 16, color=color))
    ax.text(x, z + 44, label, ha="center", va="center", color=color, fontsize=8, weight="bold")

ax.set_xlim(-HALF - ROAD - 10, HALF + ROAD + 170)
ax.set_ylim(HALF + ROAD + 10, -HALF - ROAD - 10)
ax.set_aspect("equal")
ax.set_xticks([])
ax.set_yticks([])
for spine in ax.spines.values():
    spine.set_visible(False)
ax.set_title("BLACK MARKET CITY - plan (about 1,750 x 1,750 studs)", color="white", fontsize=16, weight="bold", pad=14)
ax.text(-HALF, HALF + ROAD + 60, "Grey = roads (ring road + avenues).  Green squares = 18 trap houses.  A-E = war zone control points.", color="#A8A0C8", fontsize=9)
plt.savefig("docs/img/map_plan.png", bbox_inches="tight", facecolor=fig.get_facecolor())
print("ok")
