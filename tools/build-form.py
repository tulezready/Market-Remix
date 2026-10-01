"""
SME Information Form — MaketPles ENB
Single-page A4, designed to be printed and filled in with a pen.
"""
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.colors import Color, HexColor
from reportlab.lib.utils import ImageReader
import os

W, H = A4
M = 13 * mm                      # page margin
CW = W - 2 * M                   # content width

RED    = HexColor("#7E0F12")
GREEN  = HexColor("#00702F")
INK    = HexColor("#0C0B0A")
MUTED  = HexColor("#6B6455")
HAIR   = HexColor("#BDB6A5")
HAIR2  = HexColor("#DDD6C6")
CREAM  = HexColor("#FCFAF5")

c = canvas.Canvas("sme-form.pdf", pagesize=A4)
c.setTitle("SME Information Form — MaketPles ENB")

y = H - M   # running cursor, drops as we go


def line(x1, y1, x2, col=HAIR, w=0.6):
    c.setStrokeColor(col); c.setLineWidth(w)
    c.line(x1, y1, x2, y1)


def label(x, yy, text, size=5.6):
    c.setFont("Courier-Bold", size); c.setFillColor(MUTED)
    c.drawString(x, yy, text.upper())


def field(x, yy, w, text, size=5.6):
    """A labelled blank line for handwriting."""
    label(x, yy, text, size)
    line(x, yy - 5.5*mm, x + w)


def tickbox(x, yy, text, size=8):
    c.setStrokeColor(INK); c.setLineWidth(0.7)
    c.rect(x, yy - 0.6*mm, 3*mm, 3*mm, stroke=1, fill=0)
    c.setFont("Helvetica", size); c.setFillColor(INK)
    c.drawString(x + 4.4*mm, yy, text)
    return c.stringWidth(text, "Helvetica", size) + 9*mm


def section(yy, num, title, note=None):
    c.setFillColor(RED); c.circle(M + 2.4*mm, yy + 1.1*mm, 2.4*mm, stroke=0, fill=1)
    c.setFont("Courier-Bold", 6); c.setFillColor(HexColor("#FFFFFF"))
    c.drawCentredString(M + 2.4*mm, yy - 0.3*mm, str(num))
    c.setFont("Times-Bold", 11.5); c.setFillColor(INK)
    c.drawString(M + 7*mm, yy, title)
    if note:
        c.setFont("Helvetica-Oblique", 7); c.setFillColor(MUTED)
        c.drawRightString(M + CW, yy, note)
    return yy - 6*mm


# ---------------------------------------------------------------- header
logo = os.path.join(os.path.dirname(__file__), "..", "logo.svg")
# reportlab cannot place SVG directly; use the PNG rendered alongside it
logo_png = os.path.join(os.path.dirname(__file__), "logo-print.png")
if os.path.exists(logo_png):
    c.drawImage(ImageReader(logo_png), M, y - 13*mm, 13*mm, 13*mm,
                mask='auto', preserveAspectRatio=True)
    tx = M + 16*mm
else:
    tx = M

c.setFont("Times-Bold", 17); c.setFillColor(INK)
c.drawString(tx, y - 6*mm, "SME Information Form")
c.setFont("Courier", 6); c.setFillColor(MUTED)
c.drawString(tx, y - 10.5*mm,
             "MAKETPLES ENB  ·  DIVISION OF COMMERCE & INDUSTRY  ·  ENBPA")

# top-right admin fields
rx = M + CW - 42*mm
for i, lab in enumerate(["DATE", "COLLECTED BY", "DISTRICT"]):
    yy = y - 3*mm - i * 4.6*mm
    c.setFont("Courier-Bold", 5.2); c.setFillColor(MUTED)
    c.drawString(rx, yy, lab)
    line(rx + 19*mm, yy - 0.6*mm, M + CW)

y -= 15*mm
line(M, y, M + CW, INK, 1.4)
y -= 5.5*mm

# blurb
c.setFont("Helvetica", 7.6); c.setFillColor(MUTED)
for ln in ["The Division of Commerce & Industry is building an official online marketplace so businesses in East New Britain",
           "can sell beyond their own district. This form records what we need to put your business on it. There is no cost",
           "to you, and nothing is sold until you agree to it."]:
    c.drawString(M, y, ln); y -= 3.6*mm

y -= 2*mm
line(M, y, M + CW, HAIR2)
y -= 7*mm

# ---------------------------------------------------------------- 1. business
y = section(y, 1, "Your business")

field(M, y, CW * 0.62, "Business name — as you want buyers to see it")
field(M + CW * 0.66, y, CW * 0.34, "How long trading?")
y -= 11*mm

third = (CW - 8*mm) / 3
field(M, y, third, "Village / ward")
field(M + third + 4*mm, y, third, "LLG")
field(M + 2*(third + 4*mm), y, third, "District")
y -= 11*mm

label(M, y, "What does the business mainly do? — tick one")
y -= 5*mm
c.setFillColor(INK)
row1 = ["Retail", "Wholesale", "Tailoring", "Arts & Crafts", "Fresh produce"]
x = M
for t in row1:
    x += tickbox(x, y, t)
y -= 5.2*mm
x = M
for t in ["Food crops — rice & spices",
          "Downstream processing  (copra oil, cocoa, coffee, honey)"]:
    x += tickbox(x, y, t)
y -= 8*mm

field(M, y, CW * 0.48, "How many people work in the business?")
y -= 12*mm

# ---------------------------------------------------------------- 2. contact
y = section(y, 2, "Who we contact")

field(M, y, CW * 0.40, "Name of owner or manager")
field(M + CW * 0.44, y, CW * 0.26, "Mobile number")
field(M + CW * 0.74, y, CW * 0.26, "Second number, if any")
y -= 11*mm

field(M, y, CW * 0.40, "Email — only if you have one")
label(M + CW * 0.46, y, "Registered with IPA? — tick one")
c.setFillColor(INK)
x = M + CW * 0.46
for t in ["Yes", "Applied, waiting", "Not yet"]:
    x += tickbox(x, y - 5.5*mm, t)
y -= 13*mm

# ---------------------------------------------------------------- 3. products
y = section(y, 3, "What you sell", "Start with your three or four best sellers")

cols = [
    (6*mm,  ""),
    (CW * 0.42, "Product name"),
    (18*mm, "Price K"),
    (26*mm, "Per what?"),
    (0,     "How much do you have?"),
]
# header row
x = M
c.setFont("Courier-Bold", 5.2); c.setFillColor(MUTED)
widths = []
used = sum(w for w, _ in cols[:-1])
for w, name in cols:
    ww = w if w else (CW - used)
    widths.append(ww)
    if name:
        c.drawString(x + 1*mm, y, name.upper())
    x += ww
y -= 2.2*mm
line(M, y, M + CW, INK, 0.9)

for i in range(1, 6):
    y -= 7.6*mm
    c.setFont("Courier", 6.5); c.setFillColor(HAIR)
    c.drawString(M + 1*mm, y + 2*mm, str(i))
    line(M, y, M + CW, HAIR2)
    # faint column separators
    x = M
    c.setStrokeColor(HAIR2); c.setLineWidth(0.4)
    for ww in widths[:-1]:
        x += ww
        c.line(x, y, x, y + 7.6*mm)

y -= 8*mm
field(M, y, CW, "Is any of it seasonal? When is it available?")
y -= 12*mm

# ---------------------------------------------------------------- 4. own words
y = section(y, 4, "In your own words", "This is what buyers will read")

label(M, y, "What makes your product different from the next stall's? — how it is grown or made, and where")
y -= 2*mm
c.setStrokeColor(HAIR); c.setLineWidth(0.6)
c.rect(M, y - 15*mm, CW, 15*mm, stroke=1, fill=0)
for k in range(1, 3):
    line(M + 1*mm, y - 15*mm + k * 5*mm, M + CW - 1*mm, HAIR2, 0.4)
y -= 17*mm
c.setFont("Helvetica-Oblique", 6.6); c.setFillColor(MUTED)
c.drawString(M, y, "Two or three sentences. Your own words are better than ours.")
y -= 9*mm

# ---------------------------------------------------------------- 5. photos
y = section(y, 5, "Photographs", "Taken by the officer — tick when done")

c.setFillColor(CREAM); c.setStrokeColor(HAIR); c.setLineWidth(0.6)
box_h = 24*mm
c.rect(M, y - box_h + 4*mm, CW, box_h, stroke=1, fill=1)

py = y
items = [
    ("Each product, 2–3 shots.", " Daylight, plain background, product filling the frame."),
    ("The owner at work", " — at the stall, garden or workshop. This is the photo that makes it real."),
    ("One wide landscape shot", " for the website front page. Leave empty space on the LEFT side."),
]
for bold, rest in items:
    c.setStrokeColor(INK); c.setLineWidth(0.7)
    c.rect(M + 3*mm, py - 1*mm, 2.8*mm, 2.8*mm, stroke=1, fill=0)
    c.setFont("Helvetica-Bold", 7.4); c.setFillColor(INK)
    c.drawString(M + 7.5*mm, py, bold)
    c.setFont("Helvetica", 7.4); c.setFillColor(MUTED)
    c.drawString(M + 7.5*mm + c.stringWidth(bold, "Helvetica-Bold", 7.4), py, rest)
    py -= 5.4*mm

line(M + 3*mm, py + 1.5*mm, M + CW - 3*mm, HAIR2, 0.5)
c.setFont("Courier", 6); c.setFillColor(MUTED)
c.drawString(M + 3*mm, py - 2.4*mm,
             "FILE NAMING:  DISTRICT_Business_subject_01.jpg    e.g.  KOKOPO_Vunamami_cocoa_01.jpg")
y -= box_h + 3*mm

# ---------------------------------------------------------------- 6. consent
y = section(y, 6, "Your permission")

con_h = 27*mm
c.setFillColor(CREAM); c.setStrokeColor(INK); c.setLineWidth(1.1)
c.rect(M, y - con_h + 4*mm, CW, con_h, stroke=1, fill=1)

c.setStrokeColor(INK); c.setLineWidth(1)
c.rect(M + 3.5*mm, y - 2*mm, 3.4*mm, 3.4*mm, stroke=1, fill=0)

c.setFont("Helvetica", 7.4); c.setFillColor(INK)
tx = M + 9*mm
for ln in ["I agree to my business name, district, products, prices and photographs being shown on the MaketPles ENB website",
           "and in demonstrations of it by the Division of Commerce & Industry. I understand my phone number and any bank",
           "details are NOT shown to buyers, that I can ask for my business to be removed at any time, and that nothing is",
           "being sold yet."]:
    c.drawString(tx, y, ln); y -= 3.7*mm

y -= 4*mm
sw = (CW - 16*mm) / 2.6
field(M + 3.5*mm, y, sw, "Signature")
field(M + 3.5*mm + sw + 6*mm, y, sw, "Name in full")
field(M + 3.5*mm + 2*(sw + 6*mm), y, CW - 7*mm - 2*(sw + 6*mm), "Date")
y -= 12*mm

# ---------------------------------------------------------------- footer
line(M, M + 6*mm, M + CW, HAIR2)
c.setFont("Courier", 5.4); c.setFillColor(MUTED)
c.drawString(M, M + 3*mm,
             "MAKETPLES ENB  ·  DIVISION OF COMMERCE & INDUSTRY  ·  EAST NEW BRITAIN PROVINCIAL ADMINISTRATION")
c.drawRightString(M + CW, M + 3*mm, "NO BANK DETAILS ARE COLLECTED ON THIS FORM")

c.showPage()
c.save()
print("written: sme-form.pdf")
