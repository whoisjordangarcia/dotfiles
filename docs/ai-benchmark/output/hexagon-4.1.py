import pygame
import math
import numpy as np

# Configurations
WIDTH, HEIGHT = 800, 800
HEX_RADIUS = 300
BALL_RADIUS = 20
SPIN_SPEED = math.radians(30)  # radians per second
GRAVITY = 600  # px/s^2
FRICTION = 0.92  # velocity multiplier upon bounce
BALL_COLOR = (255, 100, 100)
HEX_COLOR = (50, 200, 255)
BG_COLOR = (30, 30, 40)
FPS = 60

pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

hex_center = np.array([WIDTH // 2, HEIGHT // 2], dtype=float)

# ==== Title setup ====
pygame.font.init()
TITLE_TEXT = "GPT-4.1"
font = pygame.font.SysFont("Arial", 56, bold=True)
title_surface = font.render(TITLE_TEXT, True, (255, 255, 255))


def hexagon_points(center, radius, angle):
    # Generate the 6 points of a hexagon rotated by angle
    pts = []
    for i in range(6):
        a = angle + i * math.pi / 3
        x = center[0] + radius * math.cos(a)
        y = center[1] + radius * math.sin(a)
        pts.append([x, y])
    return np.array(pts)


# Ball state
ball_pos = hex_center.copy()
ball_pos[1] -= 150  # Start near the top
ball_vel = np.array([120.0, -70.0])  # px/s


def reflect_velocity(vel, normal, friction):
    # Reflect vel about normal, and apply friction
    v_n = np.dot(vel, normal)
    v_t = vel - v_n * normal
    return (-v_n * normal + v_t) * friction


running = True
angle = 0
while running:
    dt = clock.tick(FPS) / 1000.0
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    # Update hexagon rotation
    angle += SPIN_SPEED * dt

    # Ball physics
    ball_vel[1] += GRAVITY * dt

    # Predict position
    next_pos = ball_pos + ball_vel * dt

    # Calculate hexagon sides (pairs of points)
    hex_pts = hexagon_points(hex_center, HEX_RADIUS, angle)
    collision = False

    for i in range(6):
        p1 = hex_pts[i]
        p2 = hex_pts[(i + 1) % 6]
        edge = p2 - p1
        edge_len = np.linalg.norm(edge)
        edge_dir = edge / edge_len
        wall_normal = np.array([-edge_dir[1], edge_dir[0]])  # outward normal

        # Compute signed distance from ball center to this wall
        rel = next_pos - p1
        proj = np.dot(rel, edge_dir)
        # Clamp projection for wall segment
        proj = np.clip(proj, 0, edge_len)
        closest = p1 + edge_dir * proj
        dist_vec = next_pos - closest
        dist = np.linalg.norm(dist_vec)
        if dist < BALL_RADIUS:
            # Collision: move ball outside wall
            collision = True
            # Push out along normal direction
            n = dist_vec / (dist if dist > 0 else 1)
            overlap = BALL_RADIUS - dist
            correction = n * overlap
            next_pos += correction
            # Reflect velocity
            ball_vel = reflect_velocity(ball_vel, n, FRICTION)
            break  # only handle first collision

    # Update ball position
    ball_pos = next_pos

    # Drawing
    screen.fill(BG_COLOR)
    # Draw hexagon
    pygame.draw.polygon(screen, HEX_COLOR, hex_pts, 6)
    # Draw Ball
    pygame.draw.circle(
        screen, BALL_COLOR, (int(ball_pos[0]), int(ball_pos[1])), BALL_RADIUS
    )

    # ==== Draw Title above hexagon ====
    title_rect = title_surface.get_rect()
    # Center horizontally
    title_rect.centerx = WIDTH // 2
    # Top edge: above the hexagon top (account for some padding)
    top_hex_y = min(hex_pts[:, 1])
    title_rect.bottom = top_hex_y - 16  # 16px padding above hexagon
    screen.blit(title_surface, title_rect)

    pygame.display.flip()

pygame.quit()
