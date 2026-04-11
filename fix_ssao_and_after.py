import os
import re

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Files to renumber: SSAO, LOOK, GRAIN, LENS, VIGNETTE, BLUR
# All need to shift by +2 to make room after CINEMATIC BORDERS (096-100)

# Process in reverse order to avoid conflicts
renames = []

# BLUR: 157-162 -> 159-164
renames.extend([
    ("162. BLUR - Soft Glow.ini", "164. BLUR - Soft Glow.ini", 164),
    ("161. BLUR - Radial Focus.ini", "163. BLUR - Radial Focus.ini", 163),
    ("160. BLUR - None (Disabled).ini", "162. BLUR - None (Disabled).ini", 162),
    ("159. BLUR - Motion Style.ini", "161. BLUR - Motion Style.ini", 161),
    ("158. BLUR - Dream Haze.ini", "160. BLUR - Dream Haze.ini", 160),
    ("157. BLUR - Depth Fade.ini", "159. BLUR - Depth Fade.ini", 159),
])

# VIGNETTE: 151-156 -> 153-158
renames.extend([
    ("156. VIGNETTE - Subtle Frame.ini", "158. VIGNETTE - Subtle Frame.ini", 158),
    ("155. VIGNETTE - Soft Vintage.ini", "157. VIGNETTE - Soft Vintage.ini", 157),
    ("154. VIGNETTE - None (Disabled).ini", "156. VIGNETTE - None (Disabled).ini", 156),
    ("153. VIGNETTE - Heavy Dramatic.ini", "155. VIGNETTE - Heavy Dramatic.ini", 155),
    ("152. VIGNETTE - Classic Portrait.ini", "154. VIGNETTE - Classic Portrait.ini", 154),
    ("151. VIGNETTE - Cinema Wide.ini", "153. VIGNETTE - Cinema Wide.ini", 153),
])

# LENS: 145-150 -> 147-152
renames.extend([
    ("150. LENS - Wide Angle.ini", "152. LENS - Wide Angle.ini", 152),
    ("149. LENS - Vintage Character.ini", "151. LENS - Vintage Character.ini", 151),
    ("148. LENS - Subtle Barrel.ini", "150. LENS - Subtle Barrel.ini", 150),
    ("147. LENS - Pincushion Correct.ini", "149. LENS - Pincushion Correct.ini", 149),
    ("146. LENS - None (Disabled).ini", "148. LENS - None (Disabled).ini", 148),
    ("145. LENS - Anamorphic.ini", "147. LENS - Anamorphic.ini", 147),
])

# GRAIN: 139-144 -> 141-146
renames.extend([
    ("144. GRAIN - Subtle Film.ini", "146. GRAIN - Subtle Film.ini", 146),
    ("143. GRAIN - None (Disabled).ini", "145. GRAIN - None (Disabled).ini", 145),
    ("142. GRAIN - Noir Gritty.ini", "144. GRAIN - Noir Gritty.ini", 144),
    ("141. GRAIN - Heavy 16mm.ini", "143. GRAIN - Heavy 16mm.ini", 143),
    ("140. GRAIN - Classic 35mm.ini", "142. GRAIN - Classic 35mm.ini", 142),
    ("139. GRAIN - Cinematic Fine.ini", "141. GRAIN - Cinematic Fine.ini", 141),
])

# LOOK: 101-138 -> 103-140
renames.extend([
    ("138. LOOK - Voyager Valo.ini", "140. LOOK - Voyager Valo.ini", 140),
    ("137. LOOK - Voyager Scorpii.ini", "139. LOOK - Voyager Scorpii.ini", 139),
    ("136. LOOK - Voyager Persephone.ini", "138. LOOK - Voyager Persephone.ini", 138),
    ("135. LOOK - Voyager Organia.ini", "137. LOOK - Voyager Organia.ini", 137),
    ("134. LOOK - Voyager Omega.ini", "136. LOOK - Voyager Omega.ini", 136),
    ("133. LOOK - Voyager Nelvana.ini", "135. LOOK - Voyager Nelvana.ini", 135),
    ("132. LOOK - Voyager Mutara.ini", "134. LOOK - Voyager Mutara.ini", 134),
    ("131. LOOK - Voyager Hypatia.ini", "133. LOOK - Voyager Hypatia.ini", 133),
    ("130. LOOK - Voyager Halka.ini", "132. LOOK - Voyager Halka.ini", 132),
    ("129. LOOK - Voyager Elora.ini", "131. LOOK - Voyager Elora.ini", 131),
    ("128. LOOK - Voyager Cruces.ini", "130. LOOK - Voyager Cruces.ini", 130),
    ("127. LOOK - Voyager Cerberus.ini", "129. LOOK - Voyager Cerberus.ini", 129),
    ("126. LOOK - Voyager Cambra.ini", "128. LOOK - Voyager Cambra.ini", 128),
    ("125. LOOK - Voyager Argus.ini", "127. LOOK - Voyager Argus.ini", 127),
    ("124. LOOK - Voyager Arcturus.ini", "126. LOOK - Voyager Arcturus.ini", 126),
    ("123. LOOK - Voyager Arakon.ini", "125. LOOK - Voyager Arakon.ini", 125),
    ("122. LOOK - Voyager Algol.ini", "124. LOOK - Voyager Algol.ini", 124),
    ("121. LOOK - Technicolor 16.ini", "123. LOOK - Technicolor 16.ini", 123),
    ("120. LOOK - Teal & Orange.ini", "122. LOOK - Teal & Orange.ini", 122),
    ("119. LOOK - Konica Centuria APS 200.ini", "121. LOOK - Konica Centuria APS 200.ini", 121),
    ("118. LOOK - Kodak UltraMax.ini", "120. LOOK - Kodak UltraMax.ini", 120),
    ("117. LOOK - Kodak Kodachrome 64.ini", "119. LOOK - Kodak Kodachrome 64.ini", 119),
    ("116. LOOK - Kodak Kodachrome 25.ini", "118. LOOK - Kodak Kodachrome 25.ini", 118),
    ("115. LOOK - Kodak 500T.ini", "117. LOOK - Kodak 500T.ini", 117),
    ("114. LOOK - Kodak 250D.ini", "116. LOOK - Kodak 250D.ini", 116),
    ("113. LOOK - Kodak 2383 D65.ini", "115. LOOK - Kodak 2383 D65.ini", 115),
    ("112. LOOK - Kodak 2383 D60.ini", "114. LOOK - Kodak 2383 D60.ini", 114),
    ("111. LOOK - Kodak 2383 D55.ini", "113. LOOK - Kodak 2383 D55.ini", 113),
    ("110. LOOK - Kodak 200T Analogica.ini", "112. LOOK - Kodak 200T Analogica.ini", 112),
    ("109. LOOK - Fujifilm 3513.ini", "111. LOOK - Fujifilm 3513.ini", 111),
    ("108. LOOK - Fuji Velvia 50.ini", "110. LOOK - Fuji Velvia 50.ini", 110),
    ("107. LOOK - FantasticoFiltro.ini", "109. LOOK - FantasticoFiltro.ini", 109),
    ("106. LOOK - Cinestill D50.ini", "108. LOOK - Cinestill D50.ini", 108),
    ("105. LOOK - Cinestill 800T.ini", "107. LOOK - Cinestill 800T.ini", 107),
    ("104. LOOK - Cinestill 800T Alternate.ini", "106. LOOK - Cinestill 800T Alternate.ini", 106),
    ("103. LOOK - Agfacolor Ultra 50.ini", "105. LOOK - Agfacolor Ultra 50.ini", 105),
    ("102. LOOK - AgfaChroma 1000RS.ini", "104. LOOK - AgfaChroma 1000RS.ini", 104),
    ("101. LOOK - Agfa RSXII 100.ini", "103. LOOK - Agfa RSXII 100.ini", 103),
])

# SSAO: 099-100 -> 101-102
renames.extend([
    ("100. SSAO - Weaker.ini", "102. SSAO - Weaker.ini", 102),
    ("099. SSAO - Stronger.ini", "101. SSAO - Stronger.ini", 101),
])

print(f"Renumbering {len(renames)} files (SSAO and after +2)...\n")

renamed_count = 0
for old_name, new_name, new_ordering in renames:
    old_path = os.path.join(overlay_dir, old_name)
    new_path = os.path.join(overlay_dir, new_name)

    if os.path.exists(old_path):
        os.rename(old_path, new_path)
        renamed_count += 1
    # Skip warning for now - will show summary

print(f"Renamed {renamed_count} files.\n")
print("Now updating UIOrdering values...\n")

# Now update UIOrdering in all renamed files
updated_count = 0
for old_name, new_name, new_ordering in renames:
    filepath = os.path.join(overlay_dir, new_name)

    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        old_match = re.search(r'UIOrdering = (\d+)', content)
        if old_match:
            content = re.sub(r'UIOrdering = \d+', f'UIOrdering = {new_ordering}', content)

            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)

            updated_count += 1

print(f"Updated UIOrdering in {updated_count} files.\n")
print("Done!")
