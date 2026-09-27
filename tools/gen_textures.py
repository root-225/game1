"""Generate app icon + flat UI icons with PIL."""
import os, math
from PIL import Image, ImageDraw, ImageFont

UI = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
ROOT = os.path.join(os.path.dirname(__file__), "..")
os.makedirs(UI, exist_ok=True)
S = 128


def new():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def rrect(d, box, r, fill):
    d.rounded_rectangle(box, radius=r, fill=fill)


def circle_btn(color):
    img = new(); d = ImageDraw.Draw(img)
    d.ellipse([6, 6, S-6, S-6], fill=(255, 255, 255, 40))
    d.ellipse([12, 12, S-12, S-12], fill=color)
    return img, d


def save(img, name):
    img.save(os.path.join(UI, name + ".png"))
    print("  ->", name)


def arrow(direction):
    img, d = circle_btn((30, 120, 200, 220))
    cx, cy = S/2, S/2
    if direction == "left":
        pts = [(cx+14, cy-26), (cx-22, cy), (cx+14, cy+26)]
    else:
        pts = [(cx-14, cy-26), (cx+22, cy), (cx-14, cy+26)]
    d.polygon(pts, fill=(255, 255, 255, 255))
    return img


def jump_icon():
    img, d = circle_btn((40, 170, 90, 220))
    cx = S/2
    d.polygon([(cx, 30), (cx-26, 66), (cx-10, 66), (cx-10, 96), (cx+10, 96), (cx+10, 66), (cx+26, 66)], fill=(255, 255, 255, 255))
    return img


def roll_icon():
    img, d = circle_btn((200, 130, 30, 220))
    d.arc([32, 32, S-32, S-32], start=20, end=300, fill=(255, 255, 255, 255), width=12)
    d.polygon([(S-40, 44), (S-24, 40), (S-30, 60)], fill=(255, 255, 255, 255))
    return img


def pause_icon():
    img, d = circle_btn((40, 40, 55, 200))
    d.rectangle([46, 42, 58, 86], fill=(255, 255, 255, 255))
    d.rectangle([70, 42, 82, 86], fill=(255, 255, 255, 255))
    return img


def play_icon():
    img, d = circle_btn((40, 170, 90, 230))
    d.polygon([(50, 40), (50, 88), (92, 64)], fill=(255, 255, 255, 255))
    return img


def coin_icon():
    img = new(); d = ImageDraw.Draw(img)
    d.ellipse([16, 16, S-16, S-16], fill=(240, 195, 40, 255))
    d.ellipse([28, 28, S-28, S-28], fill=(255, 220, 90, 255), outline=(200, 150, 20, 255), width=3)
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 46)
    except Exception:
        f = ImageFont.load_default()
    d.text((S/2, S/2), "F", font=f, anchor="mm", fill=(180, 130, 15, 255))
    return img


def shield_icon():
    img = new(); d = ImageDraw.Draw(img)
    d.polygon([(64, 14), (112, 34), (112, 74), (64, 116), (16, 74), (16, 34)], fill=(50, 150, 230, 255))
    d.polygon([(64, 28), (100, 42), (100, 72), (64, 100), (28, 72), (28, 42)], fill=(120, 200, 250, 255))
    return img


def magnet_icon():
    img = new(); d = ImageDraw.Draw(img)
    d.arc([26, 20, 102, 120], start=180, end=360, fill=(210, 40, 40, 255), width=22)
    d.rectangle([26, 78, 48, 116], fill=(210, 40, 40, 255))
    d.rectangle([80, 78, 102, 116], fill=(210, 40, 40, 255))
    d.rectangle([26, 100, 48, 116], fill=(230, 230, 235, 255))
    d.rectangle([80, 100, 102, 116], fill=(230, 230, 235, 255))
    return img


def x2_icon():
    img = new(); d = ImageDraw.Draw(img)
    d.ellipse([14, 14, S-14, S-14], fill=(240, 200, 40, 255))
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 54)
    except Exception:
        f = ImageFont.load_default()
    d.text((S/2, S/2), "x2", font=f, anchor="mm", fill=(180, 50, 40, 255))
    return img


def lock_icon():
    img = new(); d = ImageDraw.Draw(img)
    d.rounded_rectangle([34, 56, 94, 108], radius=8, fill=(90, 90, 100, 255))
    d.arc([42, 26, 86, 76], start=180, end=360, fill=(90, 90, 100, 255), width=10)
    d.ellipse([58, 74, 70, 86], fill=(230, 230, 230, 255))
    return img


def star_icon():
    img = new(); d = ImageDraw.Draw(img)
    pts = []
    for i in range(10):
        ang = -math.pi/2 + i*math.pi/5
        r = 52 if i % 2 == 0 else 22
        pts.append((64+r*math.cos(ang), 64+r*math.sin(ang)))
    d.polygon(pts, fill=(245, 205, 50, 255))
    return img


def heart_icon():
    img = new(); d = ImageDraw.Draw(img)
    d.polygon([(64, 104), (22, 60), (22, 42), (44, 32), (64, 48), (84, 32), (106, 42), (106, 60)], fill=(220, 60, 70, 255))
    d.ellipse([26, 30, 62, 66], fill=(220, 60, 70, 255))
    d.ellipse([66, 30, 102, 66], fill=(220, 60, 70, 255))
    return img


def app_icon():
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, 255, 255], radius=48, fill=(245, 150, 30, 255))
    d.rounded_rectangle([0, 0, 255, 128], radius=48, fill=(60, 160, 220, 255))
    d.rectangle([0, 90, 255, 150], fill=(60, 160, 220, 255))
    # road
    d.polygon([(96, 256), (160, 256), (150, 150), (106, 150)], fill=(40, 40, 46, 255))
    for i in range(3):
        y = 165 + i*30
        d.rectangle([124, y, 132, y+14], fill=(240, 230, 120, 255))
    # runner silhouette
    d.ellipse([116, 150, 140, 174], fill=(60, 40, 25, 255))
    d.rectangle([120, 172, 136, 210], fill=(200, 40, 40, 255))
    img.save(os.path.join(ROOT, "assets", "ui", "app_icon.png"))
    img.resize((128, 128)).save(os.path.join(ROOT, "icon.png"))
    print("  -> app_icon / icon.png")


if __name__ == "__main__":
    print("textures:")
    save(arrow("left"), "btn_left")
    save(arrow("right"), "btn_right")
    save(jump_icon(), "btn_jump")
    save(roll_icon(), "btn_roll")
    save(pause_icon(), "btn_pause")
    save(play_icon(), "btn_play")
    save(coin_icon(), "coin")
    save(shield_icon(), "shield")
    save(magnet_icon(), "magnet")
    save(x2_icon(), "x2")
    save(lock_icon(), "lock")
    save(star_icon(), "star")
    save(heart_icon(), "heart")
    app_icon()
    print("done.")
