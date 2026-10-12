// =====================================================================
//  POCKET CO2 + ENVIRONMENT MONITOR  –  2-part 3D-printable enclosure
//  Parts : "Main Base" (battery + electronics bay)  +  "Top Cover" (lid)
//  Fixing: 4 x corner screw posts (M2.5 self-tapping) + alignment tabs
//
//  HOW TO USE
//    part = "both"  -> print layout (base + lid flipped, both flat on bed)
//    part = "base"  -> Main Base only      part = "lid" -> Top Cover only
//    part = "assembled" -> closed case, only for visual checking
//    Press F6 (Render) and then File > Export > STL.
//    Command line:
//      openscad -o base.stl -D 'part="base"' co2_monitor_enclosure.scad
//      openscad -o lid.stl  -D 'part="lid"'  co2_monitor_enclosure.scad
//
//  HARDWARE
//    4 x M2.5 x 10 mm countersunk self-tapping screws (lid -> corner posts)
//    4 x M2 x 5 mm screws for the OLED (OR a dab of hot glue / tape)
//    1 x slide switch, 1 x 18650 cell + 2 spring/flat contact plates
//
//  LAYOUT (top view, X = long side)
//
//   +Y  ┌─────────────┬────────────┬──────────┬───────────┐
//       │ ESP32 │ CHG │  SCD41     │  BME280  │   (strip) │
//       │ +OLED │     │  chamber   │ chamber  │           │
//       ├─────────────┴────────────┴──────────┴───────────┤  <- divider
//       │        18650 cell, lying along X                │
//   -Y  └──────────────────────────────────────────────────┘
//    -X                                                   +X
//    Switch  : left (-X) wall      USB-C ports : +Y wall
//    SCD41 vents : +Y wall + lid   BME280 vents : +X wall + lid
//
//  PRINT SETTINGS: 0.2 mm layers, 3+ perimeters, 20 % infill, no supports.
//  PETG / ASA recommended (PLA softens in a hot car / pocket).
//  Base prints floor-down. Lid prints top-face-down (already flipped).
// =====================================================================

/* [Render control] */
part = "both";            // "both" | "base" | "lid" | "assembled"
$fn  = 60;                // smooth curves

/* [General] */
tol      = 0.3;           // clearance for every electronics pocket
wall     = 2.0;           // outer wall thickness
floor_t  = 2.0;           // base floor thickness
lid_t    = 3.0;           // lid plate thickness
Hin      = 20.5;          // free internal height above the floor
r_out    = 5.0;           // outer vertical-corner radius
fillet_b = 1.5;           // fillet on the bottom edge (base)
fillet_t = 1.5;           // fillet on the top edge (lid)
e        = 0.2;           // overlap used so unions fuse cleanly
gap      = 10;            // spacing between parts in "both" layout

/* [Screws] */
post_d      = 5.4;        // corner post diameter
post_c      = 2.5;        // post centre distance from the inner wall faces
screw_pilot = 2.1;        // pilot hole in post (M2.5 self-tapping)
pilot_depth = 9.0;
screw_clear = 2.7;        // clearance hole in lid
csk_d       = 5.4;        // countersink head diameter

/* [18650 battery] */
bat_d     = 18.5;
bat_l     = 65.0;
bat_lift  = 0.4;          // cell axis lifted above the floor
contact_w = 6.0;          // width of the contact plates

/* [ESP32-C3 SuperMini] */
esp        = [22.5, 18.0, 4.0];   // length (USB-C end), width, total height
esp_pcb_t  = 1.0;
esp_post_h = 1.5;

/* [Pidi charging module]  (dimensions assumed – edit to match yours) */
chg        = [28.0, 17.0, 4.5];   // length (port end), width, total height
chg_port   = "usbc";              // "usbc" | "micro"
chg_pcb_t  = 1.0;
chg_post_h = 1.5;

/* [SCD41 (LaskaKit board)] */
scd        = [25.0, 22.0];        // PCB 25 x 22
scd_pcb_t  = 1.6;
scd_post_h = 7.0;                 // lifts the sensor close to the lid vents

/* [BME280 (LaskaKit Pidi)] */
bme        = [10.0, 13.0, 3.0];
bme_pcb_t  = 1.0;
bme_post_h = 6.0;

/* [0.96" I2C OLED] */
oled          = [27.0, 27.0];     // PCB
oled_glass    = [26.7, 19.3];     // glass / screen window
oled_glass_dy = 3.0;              // glass centre offset toward +Y (pin header at -Y)
oled_bezel    = 1.2;              // lid bezel overlapping the glass each side
oled_glass_h  = 1.5;              // glass stands this far above the PCB face
oled_hole_pitch = [23.5, 23.5];   // PCB mounting-hole spacing
oled_post_d   = 4.0;
oled_pilot    = 1.7;              // M2 self-tapping pilot
win_chamfer   = 1.0;              // 45 deg chamfer on window (viewing angle)

/* [Mini slide switch (SS12D00 style)] */
sw_body = [11.6, 4.0, 5.0];       // length along wall, height, depth into case
sw_slot = [7.0, 2.4];             // lever slot in the wall (length, height)
sw_cy   = 32.5;                   // Y centre (inner coordinates)
sw_cz   = 9.0;                    // Z centre above floor

/* [Lid alignment tabs] */
lip_t = 1.2;
lip_h = 1.8;

// ---------------------------------------------------------------------
//  DERIVED GEOMETRY  (inner coordinates: x,y from inner wall corner,
//  z = 0 on the floor surface)
// ---------------------------------------------------------------------
base_h   = floor_t + Hin;
r_in     = r_out - wall;

// battery bay
bat_w      = bat_d + 2 * tol;
bat_cz     = bat_d / 2 + tol + bat_lift;
bat_len_pk = bat_l + 2 * tol;
div_t      = 1.6;                 // divider wall (battery | electronics)
part_t     = 1.2;                 // thermal partitions between chambers

// pockets as oriented in the case: [X size, Y size]
esp_pk  = [esp[1] + 2 * tol, esp[0] + 2 * tol];
chg_pk  = [chg[1] + 2 * tol, chg[0] + 2 * tol];
scd_pk  = [scd[1] + 2 * tol, scd[0] + 2 * tol];
bme_pk  = [bme[0] + 2 * tol, bme[1] + 2 * tol];
oled_pk = [oled[0] + 2 * tol, oled[1] + 2 * tol];

// electronics strip (beside the battery)
strip_y0 = bat_w + div_t;
strip_w  = max(chg_pk[1], oled_pk[1]) + 0.4;
Wi       = strip_y0 + strip_w;
strip_cy = strip_y0 + strip_w / 2;

// X layout of the strip
pm     = 5.4;                                    // left margin (screw post / switch)
z1_len = 0.5 + esp_pk[0] + 1.2 + chg_pk[0] + 0.5; // ESP32 + charger (+OLED above)
z2_len = scd_pk[0] + 1.2;                         // SCD41 chamber
z3_len = 14.0;                                    // BME280 chamber
Li     = max(pm + z1_len + part_t + z2_len + part_t + z3_len,
             bat_len_pk + 2 * pm);

x_z1  = pm;
x_p1  = x_z1 + z1_len;
x_z2  = x_p1 + part_t;
x_p2  = x_z2 + z2_len;

esp_cx  = x_z1 + 0.5 + esp_pk[0] / 2;
esp_cy  = Wi - 0.5 - esp_pk[1] / 2;               // USB-C end near +Y wall
chg_cx  = x_z1 + 0.5 + esp_pk[0] + 1.2 + chg_pk[0] / 2;
chg_cy  = strip_cy;
scd_cx  = x_z2 + z2_len / 2;
scd_cy  = strip_cy;
bme_cx  = Li - 0.8 - bme_pk[0] / 2;
bme_cy  = strip_y0 + 6.0 + bme_pk[1] / 2;
oled_cx = x_z1 + 0.5 + oled_pk[0] / 2;
oled_cy = strip_cy;
bat_x0  = (Li - bat_len_pk) / 2;

Lo = Li + 2 * wall;
Wo = Wi + 2 * wall;

post_pos = [[post_c, post_c], [Li - post_c, post_c],
            [post_c, Wi - post_c], [Li - post_c, Wi - post_c]];

usb_dim = (chg_port == "micro") ? [8.4, 3.4, 2.8] : [9.6, 3.9, 3.2];

echo(str("Outer size  X x Y x Z : ", Lo, " x ", Wo, " x ", base_h + lid_t, " mm"));

// ---------------------------------------------------------------------
//  HELPER MODULES
// ---------------------------------------------------------------------

// quarter "puck" with optional filleted bottom (rb) / top (rt) edge
module corner_puck(r, h, rb, rt) {
    rotate_extrude()
        intersection() {
            square([r, h]);
            hull() {
                square([0.01, h]);
                if (rb > 0) translate([r - rb, rb]) circle(r = rb);
                else        square([r, 0.01]);
                if (rt > 0) translate([r - rt, h - rt]) circle(r = rt);
                else        translate([0, h - 0.01]) square([r, 0.01]);
            }
        }
}

// rounded rectangular slab, vertical corners radius r, optional edge fillets
module rounded_slab(L, W, H, r, rb = 0, rt = 0) {
    hull()
        for (x = [r, L - r], y = [r, W - r])
            translate([x, y, 0]) corner_puck(r, H, rb, rt);
}

// stadium-shaped port cutter, runs along +Y, centred on X/Z
module usb_slot(w, h, depth) {
    rotate([-90, 0, 0])
        hull()
            for (s = [-1, 1])
                translate([s * (w - h) / 2, 0, 0]) cylinder(d = h, h = depth);
}

// PCB seat: 4 stand-offs + 4 L-shaped corner guides (0.3 mm clearance)
// origin = pocket centre, z = 0 on floor
module board_seat(bx, by, post_h, pcb_t) {
    px = bx / 2 + tol;
    py = by / 2 + tol;
    gt = 1.0;                       // guide wall thickness
    ga = 3.5;                       // guide arm length
    gh = post_h + pcb_t + 1.0;      // guide height
    for (sx = [-1, 1], sy = [-1, 1]) {
        translate([sx * (px - 2.0), sy * (py - 2.0), -e])
            cylinder(d = 3.2, h = post_h + e);
        scale([sx, sy, 1]) translate([0, 0, -e]) {
            translate([px, py - ga, 0]) cube([gt, ga + gt, gh + e]);
            translate([px - ga, py, 0]) cube([ga + gt, gt, gh + e]);
        }
    }
}

// slide-switch cradle behind the -X wall (switch drops in from above)
module switch_cradle() {
    hl = sw_body[0] / 2 + tol;
    hh = sw_body[1] / 2 + tol;
    d  = sw_body[2] + tol;
    translate([-e, -hl - 1.2, -e]) cube([d + e, 2 * hl + 2.4, sw_cz - hh + e]);
    for (s = [0, 1])
        translate([-e, s == 0 ? -hl - 1.2 : hl, -e])
            cube([d + e, 1.2, sw_cz + hh + 1.5 + e]);
}

// ---------------------------------------------------------------------
//  MAIN BASE
// ---------------------------------------------------------------------
module interior() {
    // corner screw posts
    for (p = post_pos) translate([p[0], p[1], -e]) cylinder(d = post_d, h = Hin + e);

    // divider wall between battery bay and electronics (with wire notch)
    difference() {
        translate([-e, bat_w, -e]) cube([Li + 2 * e, div_t, Hin + e]);
        translate([3.0, bat_w - 1, Hin - 6]) cube([4.0, div_t + 2, 7]);
    }

    // thermal partitions P1 / P2 around the SCD41 chamber (with wire notch)
    for (xp = [x_p1, x_p2])
        difference() {
            translate([xp, strip_y0 - e, -e]) cube([part_t, strip_w + wall / 2 + e, Hin + e]);
            translate([xp - 1, strip_y0 + 1.5, Hin - 6]) cube([part_t + 2, 4.0, 7]);
        }

    // 18650 saddle ribs
    for (xc = [bat_x0 + 8, bat_x0 + bat_len_pk / 2, bat_x0 + bat_len_pk - 8])
        difference() {
            translate([xc - 1, -e, -e]) cube([2, bat_w + 2 * e, bat_cz + e]);
            translate([xc - 2, bat_w / 2, bat_cz]) rotate([0, 90, 0])
                cylinder(r = bat_d / 2 + tol, h = 4);
        }

    // 18650 end stops (in the lower corners, clear of the contact plates)
    for (xs = [bat_x0 - 1.5, bat_x0 + bat_len_pk], ys = [-e, bat_w - 3.0])
        translate([xs, ys, -e]) cube([1.5, 3.0 + e, bat_cz * 0.9 + e]);

    // contact-plate guide ribs at both cell ends
    for (side = [0, 1], sy = [-1, 1])
        translate([side == 0 ? -e : Li - 4.0,
                   bat_w / 2 + sy * (contact_w / 2 + 0.5) - 0.5, -e])
            cube([4.0 + e, 1.0, bat_cz + 4 + e]);

    // electronics seats
    translate([esp_cx, esp_cy, 0]) board_seat(esp[1], esp[0], esp_post_h, esp_pcb_t);
    translate([chg_cx, chg_cy, 0]) board_seat(chg[1], chg[0], chg_post_h, chg_pcb_t);
    translate([scd_cx, scd_cy, 0]) board_seat(scd[1], scd[0], scd_post_h, scd_pcb_t);
    translate([bme_cx, bme_cy, 0]) board_seat(bme[0], bme[1], bme_post_h, bme_pcb_t);

    // power-switch cradle
    translate([0, sw_cy, 0]) switch_cradle();
}

module base_cutters() {
    // ESP32-C3 USB-C (+Y wall)
    translate([esp_cx, Wi - 1.5, esp_post_h + esp[2] - 1.6])
        usb_slot(9.6, 3.9, wall + 3);
    // charger USB-C / micro-USB (+Y wall)
    translate([chg_cx, Wi - 1.5, chg_post_h + chg[2] - usb_dim[2] / 2])
        usb_slot(usb_dim[0], usb_dim[1], wall + 3);
    // power switch lever slot (-X wall)
    translate([-wall - 1, sw_cy - sw_slot[0] / 2, sw_cz - sw_slot[1] / 2])
        cube([wall + 2, sw_slot[0], sw_slot[1]]);
    // SCD41 side vents (+Y wall, at sensor height)
    for (z = [11.5, 14.5, 17.5])
        translate([scd_cx - 8, Wi - 1.0, z - 0.9]) cube([16, wall + 3, 1.8]);
    // BME280 ambient vents (+X end wall)
    for (z = [7.0, 10.0, 13.0])
        translate([Li - 1.0, bme_cy - 5, z - 0.9]) cube([wall + 3, 10, 1.8]);
    // screw pilot holes
    for (p = post_pos)
        translate([p[0], p[1], Hin - pilot_depth]) cylinder(d = screw_pilot, h = pilot_depth + 1);
}

module base() {
    difference() {
        union() {
            difference() {
                rounded_slab(Lo, Wo, base_h, r_out, fillet_b, 0);
                translate([wall, wall, floor_t]) rounded_slab(Li, Wi, Hin + 1, r_in);
            }
            translate([wall, wall, floor_t]) interior();
        }
        translate([wall, wall, floor_t]) base_cutters();
    }
}

// ---------------------------------------------------------------------
//  TOP COVER  (modelled in assembled position, z = base_h ... base_h+lid_t)
// ---------------------------------------------------------------------
module lid_tabs() {
    zl = base_h - lip_h;
    // -Y wall (battery side)
    for (xr = [[12, 36], [48, 72]])
        translate([wall + xr[0], wall + tol, zl]) cube([xr[1] - xr[0], lip_t, lip_h + e]);
    // +Y wall, SCD41 chamber only (keeps clear of the OLED)
    translate([wall + x_z2 + 2, wall + Wi - tol - lip_t, zl])
        cube([z2_len - 4, lip_t, lip_h + e]);
    // battery-bay end walls
    translate([wall + tol, wall + 7, zl]) cube([lip_t, 10, lip_h + e]);
    translate([wall + Li - tol - lip_t, wall + 7, zl]) cube([lip_t, 10, lip_h + e]);
}

module oled_posts() {
    for (sx = [-1, 1], sy = [-1, 1])
        translate([wall + oled_cx + sx * oled_hole_pitch[0] / 2,
                   wall + oled_cy + sy * oled_hole_pitch[1] / 2,
                   base_h - oled_glass_h])
            cylinder(d = oled_post_d, h = oled_glass_h + e);
}

module lid_cutters() {
    top = base_h + lid_t;

    // OLED window (glass minus bezel) with 45 deg viewing chamfer
    wx = oled_glass[0] - 2 * oled_bezel;
    wy = oled_glass[1] - 2 * oled_bezel;
    cx = wall + oled_cx;
    cy = wall + oled_cy + oled_glass_dy;
    translate([cx - wx / 2, cy - wy / 2, base_h - 1]) cube([wx, wy, lid_t + 2]);
    hull() {
        translate([cx - wx / 2, cy - wy / 2, top - win_chamfer]) cube([wx, wy, 0.01]);
        translate([cx - wx / 2 - win_chamfer - 0.1, cy - wy / 2 - win_chamfer - 0.1, top + 0.1])
            cube([wx + 2 * win_chamfer + 0.2, wy + 2 * win_chamfer + 0.2, 0.01]);
    }

    // OLED screw pilots (blind, from underside)
    for (sx = [-1, 1], sy = [-1, 1])
        translate([wall + oled_cx + sx * oled_hole_pitch[0] / 2,
                   wall + oled_cy + sy * oled_hole_pitch[1] / 2,
                   base_h - oled_glass_h - 1])
            cylinder(d = oled_pilot, h = oled_glass_h + lid_t - 1.0 + 1);

    // lid screws: clearance hole + countersink
    csk_h = (csk_d - screw_clear) / 2;
    for (p = post_pos)
        translate([wall + p[0], wall + p[1], 0]) {
            translate([0, 0, base_h - 1]) cylinder(d = screw_clear, h = lid_t + 2);
            translate([0, 0, top - csk_h])
                cylinder(d1 = screw_clear, d2 = csk_d + 0.02, h = csk_h + 0.01);
        }

    // SCD41 air vents (5 slots over the chamber)
    for (i = [-2 : 2])
        translate([wall + scd_cx + i * 3.6 - 0.9, wall + scd_cy - 8, base_h - 1])
            cube([1.8, 16, lid_t + 2]);

    // BME280 air vents (3 slots)
    for (i = [-1 : 1])
        translate([wall + bme_cx + i * 3.0 - 0.8, wall + bme_cy - 5, base_h - 1])
            cube([1.6, 10, lid_t + 2]);
}

module lid() {
    difference() {
        union() {
            translate([0, 0, base_h]) rounded_slab(Lo, Wo, lid_t, r_out, 0, fillet_t);
            lid_tabs();
            oled_posts();
        }
        lid_cutters();
    }
}

// lid flipped (top face on the print bed), lowest corner at the origin
module lid_print() {
    translate([Lo, 0, base_h + lid_t]) rotate([0, 180, 0]) lid();
}

// ---------------------------------------------------------------------
//  OUTPUT
// ---------------------------------------------------------------------
if (part == "base")           base();
else if (part == "lid")       lid_print();
else if (part == "assembled") { base(); lid(); }
else {                        // "both"
    base();
    translate([Lo + gap, 0, 0]) lid_print();
}
