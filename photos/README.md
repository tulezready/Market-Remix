# Photographs

Put product and business photographs here, using the exact filenames
recorded in the intake tool.

    DISTRICT_Business_subject_01.jpg

Examples:

    KOKOPO_Vunamami_hero.jpg          <- homepage slideshow (landscape, 1800px+)
    KOKOPO_Vunamami_cocoa_01.jpg      <- product photo
    GAZELLE_Toma_blouse_01.jpg

Guidance:
  - Daylight, plain background, product filling the frame
  - Slideshow photos: landscape, clear space on the LEFT THIRD for the headline
  - Phone cameras are fine
  - Do not rename files after collection — data.json refers to them by name

Card-size copies (photos/sm/)
-----------------------------
Product cards, basket thumbnails and seller covers load a 480px-wide copy
from `photos/sm/` with the SAME filename, so pages stay fast on mobile data.
If a copy is missing, the site quietly falls back to the full photo here —
nothing breaks, it is just slower.

To make copies for new photos: resize to 480px wide, JPEG quality ~72,
save into photos/sm/ under the identical filename (any image tool works).
Keep full photos under ~1200px wide and ~250KB.
