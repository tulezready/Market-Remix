"""
MaketPles ENB — printable forms for LLG Business Development Officers.

Run:  python3 tools/build-form.py        (needs reportlab: pip install reportlab)
Writes into tools/forms/:
  officer-guide.pdf          one page for the officer: who to pick, what to do, how to return it
  sme-entry-form.pdf         the two-page form, LLG left blank
  by-llg/<District>-<LLG>.pdf  guide + form with the LLG and district already printed (one per LLG)
  all-llgs.pdf               every LLG's guide + form in one file (for reading on screen)
  print-guides-single-sided.pdf  the 20 officer guides, one page each
  print-forms-double-sided.pdf   the 20 entry forms, two pages each: print double-sided, one sheet per LLG
  llg-tracking-sheet.pdf     for the Division: which LLGs have returned a business
  instructions.pdf           3 pages: printing and handing out, entering online, reviewing entries
and copies the blank form to tools/sme-form.pdf (the file the README and register page point to).

Designed to photocopy well in black and white: white paper, dark text, firm lines.
No bank account numbers are collected on paper.
"""
import os
import shutil
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white
from reportlab.pdfgen import canvas

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "forms")

RED, GOLD, GREEN = HexColor("#C8321E"), HexColor("#E9B949"), HexColor("#2E7D3A")
INK, MUTED = HexColor("#161214"), HexColor("#4A3D36")
LINE, SOFT, TINT = HexColor("#8C857D"), HexColor("#C9BFB3"), HexColor("#F6EEDF")

# The 20 Local-level Governments of East New Britain, by district.
# Confirm against the Division's own list before printing in bulk.
LLGS = {
    "Gazelle": ["Central Gazelle Rural", "Inland Baining Rural", "Lassul Baining Rural",
                "Livuan Rural", "Reimber Rural", "Toma Rural", "Vunadidir Rural"],
    "Kokopo":  ["Bitapaka Rural", "Duke of York Rural", "Kokopo-Vunamami Urban", "Raluana Rural"],
    "Pomio":   ["Central-Inland Pomio Rural", "East Pomio Rural", "Melkoi Rural", "Sinivit Rural",
                "West Pomio-Mamusi Rural"],
    "Rabaul":  ["Balanataman Rural", "Kombiu Rural", "Rabaul Urban", "Watom Island Rural"],
}

INDUSTRIES = ["Retail", "Wholesale", "Tailoring", "Arts & crafts", "Fresh produce",
              "Food crops — rice & spices", "Downstream processing (copra oil, cocoa, coffee, honey)"]

# Where officers enter the form online. Change this when the site moves to its own domain.
ONLINE_URL = "market-remix.lesleywaninara.workers.dev/register?officer"

W, H = A4
M = 14 * mm
CW = W - 2 * M


# ---------------------------------------------------------------- drawing helpers
class Page:
    def __init__(self, c, w=W, h=H):
        self.c, self.w, self.h = c, w, h
        self.y = h - M

    def wrap(self, text, font, size, width):
        words, lines, cur = text.split(), [], ""
        for wd in words:
            t = (cur + " " + wd).strip()
            if self.c.stringWidth(t, font, size) <= width:
                cur = t
            else:
                lines.append(cur); cur = wd
        if cur:
            lines.append(cur)
        return lines

    def para(self, text, x=None, width=None, font="Helvetica", size=9, lead=None, color=INK):
        x = M if x is None else x
        width = CW if width is None else width
        lead = lead or size * 1.38
        self.c.setFont(font, size); self.c.setFillColor(color)
        for ln in self.wrap(text, font, size, width):
            self.c.drawString(x, self.y, ln)
            self.y -= lead
        return self.y

    def label(self, x, yy, text, size=6.8, color=MUTED):
        self.c.setFont("Helvetica-Bold", size); self.c.setFillColor(color)
        self.c.drawString(x, yy, text.upper())

    def rule(self, x1, yy, x2, color=LINE, w=0.7):
        self.c.setStrokeColor(color); self.c.setLineWidth(w); self.c.line(x1, yy, x2, yy)

    def field(self, x, yy, w, text, value=None, gap=7.2 * mm):
        """A label with a writing line under it; value pre-prints on the line."""
        self.label(x, yy, text)
        self.rule(x, yy - gap, x + w)
        if value:
            self.c.setFont("Helvetica-Bold", 11); self.c.setFillColor(INK)
            self.c.drawString(x + 1, yy - gap + 2.2, value)

    def box(self, x, yy, text, size=8.6):
        self.c.setStrokeColor(INK); self.c.setLineWidth(0.8)
        self.c.rect(x, yy - 0.8 * mm, 3.4 * mm, 3.4 * mm, stroke=1, fill=0)
        self.c.setFont("Helvetica", size); self.c.setFillColor(INK)
        self.c.drawString(x + 5 * mm, yy, text)
        return self.c.stringWidth(text, "Helvetica", size) + 9.5 * mm

    def boxes(self, x, yy, items, maxw, size=8.6, lead=6 * mm):
        cx = x
        for it in items:
            need = self.c.stringWidth(it, "Helvetica", size) + 9.5 * mm
            if cx + need > x + maxw:
                cx = x; yy -= lead
            cx += self.box(cx, yy, it, size)
        return yy

    def section(self, num, title, note=None):
        c = self.c
        c.setFillColor(RED); c.circle(M + 3 * mm, self.y + 1.3 * mm, 3 * mm, stroke=0, fill=1)
        c.setFont("Helvetica-Bold", 8.5); c.setFillColor(white)
        c.drawCentredString(M + 3 * mm, self.y - 0.2 * mm, str(num))
        c.setFont("Helvetica-Bold", 12.5); c.setFillColor(INK)
        c.drawString(M + 8.5 * mm, self.y, title)
        if note:
            c.setFont("Helvetica-Oblique", 8); c.setFillColor(MUTED)
            c.drawRightString(M + CW, self.y, note)
        self.y -= 3.2 * mm
        self.rule(M, self.y, M + CW, color=SOFT, w=0.6)
        self.y -= 6 * mm

    def ribbon(self, yy, x1=M, x2=None):
        """The tambu-style stripe used on the website, in three thin bars."""
        x2 = x2 or (M + CW)
        for i, col in enumerate((RED, GOLD, GREEN)):
            self.c.setFillColor(col); self.c.rect(x1, yy - i * 1.3 * mm, x2 - x1, 1 * mm, stroke=0, fill=1)

    def footer(self, text, page_no=None, pages=None):
        c = self.c
        self.rule(M, M + 4 * mm, self.w - M, color=SOFT, w=0.5)
        c.setFont("Helvetica", 7); c.setFillColor(MUTED)
        c.drawString(M, M, text)
        if page_no:
            c.drawRightString(self.w - M, M, f"Page {page_no} of {pages}")


def header(p, title, subtitle, llg=None, district=None, show_form_no=True, show_box=True):
    c = p.c
    top = p.h - M
    c.setFont("Helvetica-Bold", 19); c.setFillColor(INK)
    c.drawString(M, top - 6 * mm, "MaketPles")
    c.setFillColor(RED); c.drawString(M + c.stringWidth("MaketPles ", "Helvetica-Bold", 19), top - 6 * mm, "ENB")
    c.setFont("Helvetica-Bold", 13); c.setFillColor(INK)
    c.drawString(M, top - 13 * mm, title)
    c.setFont("Helvetica", 8); c.setFillColor(MUTED)
    c.drawString(M, top - 17.5 * mm, subtitle)

    # right-hand box: where this form belongs
    if not show_box:
        p.ribbon(top - 22.5 * mm); p.y = top - 30 * mm
        return
    bw, bh = 74 * mm, 21 * mm
    bx, by = M + CW - bw, top - bh
    c.setStrokeColor(INK); c.setLineWidth(0.9); c.setFillColor(TINT)
    c.rect(bx, by, bw, bh, stroke=1, fill=1)
    rows = [("LLG", llg), ("District", district)] + ([("Form no.", None)] if show_form_no else [])
    for i, (k, v) in enumerate(rows):
        yy = top - 5.6 * mm - i * 6.4 * mm
        p.label(bx + 3 * mm, yy, k, size=6.8)
        if v:
            size = 9.5 if c.stringWidth(v, "Helvetica-Bold", 9.5) < bw - 22 * mm else 8
            c.setFont("Helvetica-Bold", size); c.setFillColor(INK)
            c.drawString(bx + 19 * mm, yy, v)
        else:
            p.rule(bx + 19 * mm, yy - 1, bx + bw - 3 * mm, color=LINE, w=0.6)
    p.ribbon(top - 22.5 * mm)
    p.y = top - 30 * mm


FOOT = "MaketPles ENB · Division of Commerce & Industry, East New Britain Provincial Administration · No bank account numbers are collected on paper"


# ---------------------------------------------------------------- officer guide (1 page)
def officer_guide(c, llg=None, district=None):
    p = Page(c)
    header(p, "Find one business from your LLG",
           "For LLG Business Development Officers",
           llg, district, show_form_no=False)

    p.para("The Division is putting East New Britain businesses on MaketPles ENB, an online marketplace "
           "where people across PNG, and family working away from home, can buy from them. We are asking "
           "every LLG for at least one business for the launch at the Division's conference in November.",
           size=9.6)
    p.y -= 3 * mm

    def block(title, items, numbered=False):
        p.c.setFont("Helvetica-Bold", 11); p.c.setFillColor(RED)
        p.c.drawString(M, p.y, title); p.y -= 5.6 * mm
        for i, it in enumerate(items, 1):
            mark = f"{i}." if numbered else "•"
            p.c.setFont("Helvetica-Bold" if numbered else "Helvetica", 9.4); p.c.setFillColor(INK)
            p.c.drawString(M + 1 * mm, p.y, mark)
            p.para(it, x=M + 6 * mm, width=CW - 6 * mm, size=9.4)
            p.y -= 0.8 * mm
        p.y -= 2.4 * mm

    block("Who to choose", [
        "A business that is running now in your LLG and sells something people would buy: produce, food "
        "crops, crafts, sewing, processed goods (copra oil, cocoa, coffee, honey), a trade store or wholesaler.",
        "The owner wants to take part and can be reached on a mobile number.",
        "IPA registration is preferred, but not needed for the pilot — the Division approves unregistered "
        "businesses case by case and can help them register.",
        "If you find more than one good business, fill in a form for each. One is the minimum.",
    ])
    block("On the visit", [
        "Explain the marketplace using the points below. Ask the owner to read section 7 or read it to them.",
        "Fill in the form with the owner, in their words. Write prices in kina and say what each price is for "
        "(each, per kg, per bundle).",
        "Take the photos listed in section 5 with your phone, in daylight.",
        "The owner signs section 7. You sign the officer's part. Without both signatures we cannot list them.",
        f"Enter the form online on your phone at  {ONLINE_URL}  and add the photos there. "
        "Keep the signed paper form for your records.",
    ], numbered=True)
    block("What to tell the owner — honestly", [
        "Joining is free. When selling starts, a small fee is taken from each sale. The Division will explain it "
        "before anything is sold, and the owner can say no.",
        "Nothing is sold yet. This form only gets the business ready to be listed.",
        "Their phone number is never shown to buyers. Bank details are not collected on this form.",
        "They can ask for their business to be removed at any time.",
    ])

    # return box
    p.y -= 1 * mm
    bh = 38 * mm
    c.setStrokeColor(INK); c.setLineWidth(0.9); c.setFillColor(TINT)
    c.rect(M, p.y - bh, CW, bh, stroke=1, fill=1)
    c.setFont("Helvetica-Bold", 11); c.setFillColor(INK)
    c.drawString(M + 4 * mm, p.y - 6.5 * mm, "If you can't enter it online, return the form and photos")
    half = (CW - 12 * mm) / 2
    p.field(M + 4 * mm, p.y - 13 * mm, half, "Return by (date)")
    p.field(M + 8 * mm + half, p.y - 13 * mm, half, "To (name at the Division)")
    p.field(M + 4 * mm, p.y - 26 * mm, half, "Send photos by WhatsApp or email to")
    p.field(M + 8 * mm + half, p.y - 26 * mm, half, "Questions — phone")
    p.y -= bh + 4 * mm

    p.para("Photo file names: DISTRICT_Business_subject_01.jpg — for example GAZELLE_Abuta_seedlings_01.jpg. "
           "If renaming is hard, send the photos in a message that starts with the business name.",
           size=8.4, color=MUTED)
    p.footer(FOOT)
    c.showPage()


# ---------------------------------------------------------------- entry form (2 pages)
def entry_form(c, llg=None, district=None):
    # ---- page 1
    p = Page(c)
    header(p, "SME Entry Form", "Filled in by the LLG Business Development Officer with the business owner",
           llg, district)
    p.para("This form puts a business on MaketPles ENB, the Division's online marketplace. Write clearly in "
           "capital letters. Leave a box empty if it does not apply.", size=9.2)
    p.y -= 4 * mm

    p.section(1, "The business")
    p.field(M, p.y, CW * 0.70, "Business name — as buyers should see it")
    p.field(M + CW * 0.74, p.y, CW * 0.26, "Trading for how long?")
    p.y -= 13 * mm
    p.field(M, p.y, CW * 0.36, "Ward or village")
    p.field(M + CW * 0.40, p.y, CW * 0.34, "LLG" if llg else "LLG — one of your district's LLGs", llg)
    p.field(M + CW * 0.78, p.y, CW * 0.22, "District", district)
    p.y -= 13 * mm
    p.label(M, p.y, "What does the business mainly sell? Tick one")
    p.y -= 6 * mm
    p.y = p.boxes(M, p.y, INDUSTRIES, CW) - 9 * mm
    p.label(M, p.y, "Registered with IPA? Tick one")
    p.label(M + CW * 0.55, p.y, "IPA number, if registered")
    p.boxes(M, p.y - 6 * mm, ["Yes", "Applied, waiting", "Not yet"], CW * 0.52)
    p.rule(M + CW * 0.55, p.y - 7.2 * mm, M + CW)
    p.y -= 15 * mm
    p.field(M, p.y, CW * 0.30, "How many people work in it?")
    p.y -= 15 * mm

    p.section(2, "Who we contact")
    p.field(M, p.y, CW * 0.48, "Owner or manager — full name")
    p.field(M + CW * 0.52, p.y, CW * 0.23, "Mobile number")
    p.field(M + CW * 0.79, p.y, CW * 0.21, "Second number")
    p.y -= 13 * mm
    p.field(M, p.y, CW * 0.60, "Email — only if they have one")
    p.y -= 15 * mm

    p.section(3, "What they sell", "Start with the three or four best sellers")
    cols = [("Product — include size or weight", 0.44), ("Price K", 0.12), ("Per what?", 0.17),
            ("How many now?", 0.15), ("Fresh?", 0.12)]
    x = M
    for name, f in cols:
        p.label(x + 1 * mm, p.y, name, size=6.6); x += CW * f
    p.y -= 2.4 * mm
    rh = 9.2 * mm
    rows = 6
    c.setStrokeColor(LINE); c.setLineWidth(0.6)
    for r in range(rows + 1):
        c.line(M, p.y - r * rh, M + CW, p.y - r * rh)
    x = M
    for _, f in cols[:-1]:
        x += CW * f
        c.line(x, p.y, x, p.y - rows * rh)
    for r in range(rows):
        c.setFont("Helvetica-Bold", 7.5); c.setFillColor(MUTED)
        c.drawString(M + 1 * mm, p.y - r * rh - 3.6 * mm, str(r + 1))
        bx = M + CW * 0.88 + 4 * mm
        c.setStrokeColor(INK); c.rect(bx, p.y - r * rh - 6 * mm, 3.4 * mm, 3.4 * mm, stroke=1, fill=0)
        c.setStrokeColor(LINE)
    p.y -= rows * rh + 8 * mm
    p.field(M, p.y, CW, "Is any of it seasonal? When is it available?")
    p.footer(FOOT, 1, 2)
    c.showPage()

    # ---- page 2
    p = Page(c)
    p.c.setFont("Helvetica-Bold", 10); p.c.setFillColor(INK)
    p.c.drawString(M, p.y - 3 * mm, "SME Entry Form — continued")
    p.c.setFont("Helvetica", 8.5); p.c.setFillColor(MUTED)
    p.c.drawRightString(M + CW, p.y - 3 * mm, f"LLG: {llg}" if llg else "LLG: ______________________________")
    p.ribbon(p.y - 6.5 * mm)
    p.y -= 15 * mm

    p.section(4, "In the owner's own words", "This is what buyers will read")
    p.label(M, p.y, "What makes the product good? How and where is it grown or made?")
    p.y -= 3 * mm
    for _ in range(4):
        p.y -= 8 * mm; p.rule(M, p.y, M + CW)
    p.y -= 11 * mm

    p.section(5, "Photographs", "Taken by the officer — tick when done")
    for t in ["Each product: 2 or 3 photos. Daylight, plain background, the product filling the frame.",
              "The owner at work — at the stall, garden or workshop. This is the photo that makes it real.",
              "One wide photo of the place, for the website front page. Leave empty space on the left side."]:
        p.box(M, p.y, t, size=8.8); p.y -= 6.6 * mm
    p.c.setFont("Helvetica", 8.2); p.c.setFillColor(MUTED)
    p.c.drawString(M, p.y, "File names: DISTRICT_Business_subject_01.jpg   e.g.  KOKOPO_Vunamami_cocoa_01.jpg")
    p.y -= 10 * mm

    p.section(6, "Getting paid", "Information only — no account numbers here")
    p.label(M, p.y, "Does the business have a bank account for payments? Tick one")
    p.boxes(M, p.y - 6 * mm, ["Yes, in the business name", "Yes, in the owner's name", "No bank account yet"], CW)
    p.y -= 12 * mm
    p.para("The Division confirms bank details with the owner by phone later. Never write an account number "
           "or PIN on this form.", size=8.2, color=MUTED)
    p.y -= 6 * mm

    p.section(7, "Permission and signatures")
    p.box(M, p.y, "I agree to my business name, district, products, prices and photos being shown on MaketPles ENB", size=8.6)
    p.y -= 4.6 * mm
    p.para("and in demonstrations by the Division of Commerce & Industry. I understand that my phone number is not "
           "shown to buyers, that joining is free and a fee on each sale will be explained before anything is sold, "
           "and that I can ask for my business to be removed at any time.", x=M + 5 * mm, width=CW - 5 * mm, size=8.6)
    p.y -= 6 * mm
    third = (CW - 8 * mm) / 3
    p.field(M, p.y, third, "Owner — name")
    p.field(M + third + 4 * mm, p.y, third, "Owner — signature or mark")
    p.field(M + 2 * (third + 4 * mm), p.y, third, "Date")
    p.y -= 14 * mm
    p.para("Officer: I visited this business and the owner gave the details above.", size=8.6)
    p.y -= 2 * mm
    p.field(M, p.y, third, "Officer — name")
    p.field(M + third + 4 * mm, p.y, third, "Signature")
    p.field(M + 2 * (third + 4 * mm), p.y, third, "Officer's mobile")
    p.y -= 15 * mm

    # office use
    bh = 22 * mm
    c.setStrokeColor(INK); c.setLineWidth(0.8); c.setFillColor(TINT)
    c.rect(M, p.y - bh, CW, bh, stroke=1, fill=1)
    p.label(M + 3 * mm, p.y - 5 * mm, "For Division use", size=7.4, color=INK)
    q = (CW - 15 * mm) / 4
    for i, t in enumerate(["Received by", "Date received", "Photos received", "Entered online — ref."]):
        p.field(M + 3 * mm + i * (q + 3 * mm), p.y - 11 * mm, q, t, gap=6.5 * mm)
    p.footer(FOOT, 2, 2)
    c.showPage()


# ---------------------------------------------------------------- tracking sheet (landscape)
def tracking_sheet(path):
    LW, LH = landscape(A4)
    c = canvas.Canvas(path, pagesize=(LW, LH))
    c.setTitle("LLG tracking sheet — MaketPles ENB"); c.setAuthor("Division of Commerce & Industry, ENBPA")
    p = Page(c, LW, LH)
    cw = LW - 2 * M
    c.setFont("Helvetica-Bold", 16); c.setFillColor(INK)
    c.drawString(M, LH - M - 5 * mm, "One business from every LLG — tracking sheet")
    c.setFont("Helvetica", 8.5); c.setFillColor(MUTED)
    c.drawString(M, LH - M - 10.5 * mm, "MaketPles ENB · Division of Commerce & Industry, ENBPA · Tick each column as the form, photos and online entry come in.")
    p.ribbon(LH - M - 13.5 * mm, M, M + cw)
    cols = [("District", 0.07), ("LLG", 0.15), ("Officer", 0.13), ("Mobile", 0.09),
            ("Business found", 0.16), ("What it sells", 0.11), ("Form back", 0.08),
            ("Photos", 0.06), ("Online", 0.06), ("Notes", 0.09)]
    y = LH - M - 21 * mm
    x = M
    c.setFillColor(INK); c.rect(M, y - 2.6 * mm, cw, 7 * mm, stroke=0, fill=1)
    for name, f in cols:
        c.setFont("Helvetica-Bold", 7.2); c.setFillColor(white)
        c.drawString(x + 1.5 * mm, y, name.upper()); x += cw * f
    y -= 2.6 * mm
    rh = min(8.1 * mm, (y - M - 6 * mm) / sum(len(v) for v in LLGS.values()))
    c.setLineWidth(0.5)
    for d, llgs in LLGS.items():
        for i, l in enumerate(llgs):
            if i % 2:
                c.setFillColor(TINT); c.rect(M, y - rh, cw, rh, stroke=0, fill=1)
            c.setFillColor(INK); c.setFont("Helvetica-Bold" if i == 0 else "Helvetica", 8)
            c.drawString(M + 1.5 * mm, y - rh + 2.8 * mm, d if i == 0 else "")
            c.setFont("Helvetica", 8.4); c.drawString(M + cw * 0.07 + 1.5 * mm, y - rh + 2.8 * mm, l)
            c.setStrokeColor(SOFT); c.line(M, y - rh, M + cw, y - rh)
            y -= rh
        c.setStrokeColor(INK); c.line(M, y, M + cw, y)
    x = M
    c.setStrokeColor(SOFT)
    for _, f in cols[:-1]:
        x += cw * f; c.line(x, LH - M - 23.6 * mm, x, y)
    c.setFont("Helvetica", 7); c.setFillColor(MUTED)
    c.drawString(M, M, "LLG list: confirm against the Division's records. Target: at least one business per LLG (20 LLGs) toward the 35-business launch cohort.")
    c.showPage(); c.save()



# ---------------------------------------------------------------- instructions (3 pages)
def instructions(path):
    c = doc(path, "LLG trial — instructions — MaketPles ENB")

    def page_top(p, title, sub):
        header(p, title, sub, None, None, show_form_no=False, show_box=False)

    def h(p, text):
        p.y -= 1.5 * mm
        p.c.setFont("Helvetica-Bold", 12); p.c.setFillColor(RED)
        p.c.drawString(M, p.y, text); p.y -= 6 * mm

    def items(p, rows, numbered=True, size=9.6):
        for i, it in enumerate(rows, 1):
            p.c.setFont("Helvetica-Bold" if numbered else "Helvetica", size); p.c.setFillColor(INK)
            p.c.drawString(M + 1 * mm, p.y, f"{i}." if numbered else "•")
            p.para(it, x=M + 7 * mm, width=CW - 7 * mm, size=size)
            p.y -= 1.2 * mm
        p.y -= 2 * mm

    def table(p, head, rows, widths, size=9):
        x0, rh = M, 7.5 * mm
        c.setFillColor(INK); c.rect(M, p.y - 2.4 * mm, CW, 7 * mm, stroke=0, fill=1)
        x = x0
        for t, w in zip(head, widths):
            c.setFont("Helvetica-Bold", 8); c.setFillColor(white); c.drawString(x + 2 * mm, p.y, t.upper()); x += CW * w
        p.y -= 2.4 * mm
        for i, r in enumerate(rows):
            lines = [p.wrap(cell, "Helvetica", size, CW * w - 4 * mm) for cell, w in zip(r, widths)]
            hgt = max(len(l) for l in lines) * size * 1.35 + 3.5 * mm
            if i % 2:
                c.setFillColor(TINT); c.rect(M, p.y - hgt, CW, hgt, stroke=0, fill=1)
            x = x0
            for ls, w in zip(lines, widths):
                yy = p.y - 3 * mm - size * 0.8
                for ln in ls:
                    c.setFont("Helvetica", size); c.setFillColor(INK); c.drawString(x + 2 * mm, yy, ln); yy -= size * 1.35
                x += CW * w
            p.y -= hgt
            p.rule(M, p.y, M + CW, color=SOFT, w=0.5)
        p.y -= 5 * mm

    # ---- page 1: what, print, hand out
    p = Page(c)
    page_top(p, "LLG trial — instructions", "Getting the first businesses onto MaketPles ENB through the LLGs")
    p.para("Every LLG Business Development Officer finds at least one business in their LLG, fills in the paper form "
           "with the owner, and enters it online with photos. The entry goes straight to the Division for review. "
           "There are 20 LLGs and the launch target is 35 businesses, so ask each officer for two where they can.",
           size=9.8)
    p.y -= 2 * mm
    h(p, "1. Print")
    table(p, ["File", "How to print", "Sheets"], [
        ["print-guides-single-sided.pdf", "A4, single-sided", "20 — one officer guide per LLG"],
        ["print-forms-double-sided.pdf", "A4, double-sided, flip on long edge", "20 — each LLG's form on one sheet"],
        ["sme-entry-form.pdf", "A4, double-sided — a few spares", "For an officer's second business"],
        ["llg-tracking-sheet.pdf", "A4 landscape, single-sided", "1 — kept by the Division"],
    ], [0.36, 0.34, 0.30])
    p.para("Each guide and form already shows its LLG and district. The by-llg folder has the same for one LLG at a "
           "time, if you need to reprint just one. Photocopies in black and white are fine.", size=8.8, color=MUTED)
    h(p, "2. Before handing out")
    items(p, [
        "Fill in the return box on every guide: the return date, who it goes to at the Division, where to send "
        "photos, and a phone for questions. Allow about three weeks before the conference for review.",
        "Check the LLG names against the Division's list.",
        "Give each officer their LLG's guide and form, plus a spare form.",
        "Write each officer's name and mobile on the tracking sheet.",
    ])
    h(p, "3. What the officer does")
    items(p, [
        "Chooses a business and visits it (the guide explains who to choose and what to tell the owner).",
        "Fills in the paper form with the owner, takes the photos, and both sign.",
        "Enters the form online with the photos (page 2 of these instructions).",
        "Writes the online reference (for example ENB-A1234) on the paper form and keeps it for their records.",
    ])
    p.footer(FOOT, 1, 3)
    c.showPage()

    # ---- page 2: officer online entry
    p = Page(c)
    page_top(p, "Entering a business online", "For LLG Business Development Officers — on a phone")
    c.setFillColor(TINT); c.setStrokeColor(INK); c.setLineWidth(0.9)
    c.rect(M, p.y - 15 * mm, CW, 15 * mm, stroke=1, fill=1)
    c.setFont("Helvetica-Bold", 9); c.setFillColor(MUTED); c.drawString(M + 4 * mm, p.y - 5 * mm, "OPEN THIS ADDRESS")
    c.setFont("Helvetica-Bold", 13); c.setFillColor(INK); c.drawString(M + 4 * mm, p.y - 11.5 * mm, ONLINE_URL)
    p.y -= 22 * mm
    p.para("Save it to the phone's home screen. Type it exactly, including ?officer at the end — that adds the "
           "officer's section and tells the Division the entry came from an LLG officer.", size=9.4)
    p.y -= 1 * mm
    h(p, "Step by step — copy from the paper form")
    items(p, [
        "About the business: name and district; then choose the LLG from the list (or \"Not sure\") and type "
        "the ward or village in its own box; then how long trading, staff, what it mainly sells, and the "
        "owner's description from section 4.",
        "Contact: the owner's name, mobile and email if any.",
        "Registration: IPA status, and the IPA number if they have one.",
        "What they sell: each product with its price in kina, what the price is for (each, per kg, per bundle), "
        "and how many they have.",
        "Photos: up to 12, made smaller automatically so they send on a weak signal. With one product, its photos "
        "go to it by themselves. With more than one, choose under each photo which product it shows — or the owner "
        "at work, or the wide photo of the place. The form reminds you if a photo isn't sorted, or if there is no "
        "photo of the owner or the place.",
        "Check and send: check everything, enter your own name, mobile and the paper form number, tick that "
        "the owner signed the paper form, and press Send.",
        "Write the reference shown (for example ENB-A1234) on the paper form. Press \"Register another "
        "business\" for the next one — your name and mobile are remembered on that phone.",
    ])
    h(p, "If there is no signal")
    items(p, [
        "If sending fails, stay on the page and press Send again when the signal returns. Nothing is lost while "
        "the page stays open.",
        "If there is no coverage at all, keep the paper form and enter it later where there is signal — or return "
        "the form and photos to the Division as the guide's return box says.",
    ], numbered=False)
    h(p, "Good to know")
    items(p, [
        "Nothing appears on the website until the Division has checked and approved it.",
        "Never type a bank account number or PIN into the form.",
    ], numbered=False)
    p.footer(FOOT, 2, 3)
    c.showPage()

    # ---- page 3: Division review
    p = Page(c)
    page_top(p, "Reviewing entries", "For Division staff — in the Division panel (admin.html)")
    h(p, "Each new entry")
    items(p, [
        "Division panel (" + ONLINE_URL.split("/register")[0] + "/admin) → Business applications. Entries from officers are labelled \"LLG officer\"; the note "
        "shows the officer's name, mobile, paper form number and the IPA number.",
        "Phone the owner on the number given. Confirm the details, that they agreed to be listed, and the prices. "
        "Aim to do this within 2 working days so officers see results.",
        "Open the entry. Check the LLG and ward, and under each photo check what it shows: the menu lists the "
        "products by name, plus me / my stall and front page. Fix any photo before approving.",
        "Approve & create account — or Return to applicant with a note saying what is needed. If photos are "
        "missing from the listing afterwards, open the application again and press Move photos again.",
        "Listing review: check each product (photo, description, price) and Publish it.",
        "Businesses → open the business → Seller login → Create login. Give the owner the login and temporary "
        "password in person or by phone; they choose their own at first sign-in.",
        "Tick the business off on the tracking sheet.",
    ])
    h(p, "Each week")
    items(p, [
        "Launch progress screen: shows how many businesses per industry (target 5 in each of 7) and per district. "
        "Tell officers what is missing — for example \"we need tailoring from Pomio\".",
        "Phone officers whose LLG has nothing yet.",
    ], numbered=False)
    h(p, "Keep in mind")
    items(p, [
        "The officer's address is open to anyone with the link, but nothing goes public without Division approval. "
        "Reject anything you cannot confirm by phone.",
        "Unregistered businesses can be approved during the pilot, case by case.",
        "Sample businesses on the site are placeholders; they are removed before launch.",
        "To take a business off the site: Businesses → Open → Remove from site. Its records are kept and it can be "
        "put back. Delete permanently is for test entries with no orders only, and only Division admins see it.",
    ], numbered=False)
    p.footer(FOOT, 3, 3)
    c.showPage()
    c.save()

# ---------------------------------------------------------------- build everything
def doc(path, title):
    c = canvas.Canvas(path, pagesize=A4)
    c.setTitle(title); c.setAuthor("Division of Commerce & Industry, ENBPA"); c.setSubject("MaketPles ENB")
    return c


def slug(s):
    return "".join(ch if ch.isalnum() else "-" for ch in s).strip("-").replace("--", "-")


def main():
    os.makedirs(os.path.join(OUT, "by-llg"), exist_ok=True)

    c = doc(os.path.join(OUT, "officer-guide.pdf"), "Officer guide — MaketPles ENB")
    officer_guide(c); c.save()

    c = doc(os.path.join(OUT, "sme-entry-form.pdf"), "SME Entry Form — MaketPles ENB")
    entry_form(c); c.save()
    shutil.copy(os.path.join(OUT, "sme-entry-form.pdf"), os.path.join(HERE, "sme-form.pdf"))

    # Print files: guides single-sided (20 sheets); forms double-sided, one sheet per LLG (20 sheets).
    allc = doc(os.path.join(OUT, "all-llgs.pdf"), "SME Entry Forms, all LLGs — MaketPles ENB")
    guides = doc(os.path.join(OUT, "print-guides-single-sided.pdf"), "Officer guides, all LLGs — MaketPles ENB")
    forms = doc(os.path.join(OUT, "print-forms-double-sided.pdf"), "SME Entry Forms, all LLGs — MaketPles ENB")
    for d, llgs in LLGS.items():
        for l in llgs:
            c = doc(os.path.join(OUT, "by-llg", f"{d}-{slug(l)}.pdf"), f"{l} — SME Entry Form — MaketPles ENB")
            officer_guide(c, l, d + " District"); entry_form(c, l, d + " District"); c.save()
            officer_guide(allc, l, d + " District"); entry_form(allc, l, d + " District")
            officer_guide(guides, l, d + " District"); entry_form(forms, l, d + " District")
    allc.save(); guides.save(); forms.save()

    tracking_sheet(os.path.join(OUT, "llg-tracking-sheet.pdf"))
    instructions(os.path.join(OUT, "instructions.pdf"))
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
