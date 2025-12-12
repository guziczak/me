@goto :python
import time,ctypes,subprocess,sys,os,random,threading
os.system('')

# Muzyka - climax motif (synteza do pamieci, bez plikow)
import math,struct,io,winsound

MOTIF = [
    ('E4', 0, 4, 0.65), ('A4', 0, 4, 0.7), ('E5', 0, 1.5, 1.0),
    ('D5', 1.5, 0.5, 0.92), ('C5', 2, 1, 0.98), ('B4', 3, 0.5, 0.90), ('A4', 3.5, 0.5, 0.88),
    ('G4', 4, 0.75, 0.90), ('A4', 4.75, 0.25, 0.86), ('B4', 5, 1.5, 0.98),
    ('C5', 6.5, 1, 0.95), ('D5', 7.5, 0.5, 0.92),
    ('E5', 8, 0.75, 1.0), ('F5', 8.75, 0.25, 0.96), ('G5', 9, 1, 1.0),
    ('A5', 10, 1, 1.0), ('G5', 11, 0.5, 0.98), ('F5', 11.5, 0.5, 0.92),
    ('E5', 12, 1.5, 1.0), ('D5', 13.5, 0.5, 0.92),
    ('C5', 14, 0.5, 0.96), ('B4', 14.5, 0.5, 0.90), ('A4', 15, 1, 0.98)
]
FREQ = {'G4': 392, 'A4': 440, 'B4': 494, 'C5': 523, 'D5': 587,
        'E4': 330, 'E5': 659, 'F5': 698, 'G5': 784, 'A5': 880}
TEMPO = 103
SR = 16000  # Nizszy SR = szybsze generowanie

def generate_wav_memory():
    """Generuj WAV do pamieci - synteza skrzypiec z vibrato, bow noise, jitter"""
    sec_per_beat = 60 / TEMPO
    total_samples = int(16 * sec_per_beat * SR)
    audio = [0.0] * total_samples

    for note, start_beat, dur_beats, vel in MOTIF:
        f = FREQ[note]
        start_sample = int(start_beat * sec_per_beat * SR)
        dur_sec = dur_beats * sec_per_beat
        num_samples = int(dur_sec * SR)

        phase = 0.0
        phase2 = 0.0  # dla 2. harmonicznej
        samples = []

        # Parametry
        vib_delay = 0.15  # vibrato zaczyna sie po 0.15s
        vib_rate = 5.5
        vib_depth = 0.006

        for i in range(num_samples):
            t = i / SR

            # Opoznione vibrato - narasta stopniowo
            vib_amount = 0.0
            if t > vib_delay:
                vib_fade = min(1.0, (t - vib_delay) / 0.2)  # narasta przez 0.2s
                vib_amount = math.sin(2 * math.pi * vib_rate * t) * f * vib_depth * vib_fade

            # Jitter - male losowe odchylenia (symuluje niestabilnosc)
            jitter = (random.random() - 0.5) * f * 0.002

            freq_now = f + vib_amount + jitter
            phase += 2 * math.pi * freq_now / SR
            phase2 += 2 * math.pi * (freq_now * 2) / SR  # 2. harmoniczna

            # Sawtooth + wzmocniona 2. harmoniczna (charakterystyka skrzypiec)
            saw = 2 * ((phase / (2 * math.pi)) % 1) - 1
            harm2 = math.sin(phase2) * 0.3  # 2. harmoniczna
            wave = saw * 0.7 + harm2

            # Bow noise - szum smyczka na ataku
            bow_noise = 0.0
            if t < 0.08:
                noise_amount = (1 - t / 0.08) * 0.15  # zanika przez 80ms
                bow_noise = (random.random() - 0.5) * noise_amount

            # Envelope ADSR z "bite" smyczka
            env = 1.0
            att = int(0.04 * SR)   # szybki atak
            decay = int(0.08 * SR) # decay po ataku
            rel = int(0.12 * SR)   # release

            if i < att:
                # Atak z lekkim overshoot (bite)
                env = (i / att) * 1.15
            elif i < att + decay:
                # Decay do sustain
                decay_pos = (i - att) / decay
                env = 1.15 - decay_pos * 0.2  # z 1.15 do 0.95
            elif i > num_samples - rel:
                env = 0.95 * (num_samples - i) / rel
            else:
                env = 0.95  # sustain

            sample = (wave + bow_noise) * env * vel * 0.11
            samples.append(sample)

        # Lowpass - rezonans pudla
        for i in range(1, len(samples)):
            samples[i] = 0.35 * samples[i] + 0.65 * samples[i-1]

        for i, s in enumerate(samples):
            idx = start_sample + i
            if idx < total_samples:
                audio[idx] += s

    max_val = max(abs(s) for s in audio) or 1
    audio = [s / max_val * 0.7 for s in audio]

    # Buduj WAV w pamieci
    buf = io.BytesIO()
    # RIFF header
    data_size = len(audio) * 2
    buf.write(b'RIFF')
    buf.write(struct.pack('<I', 36 + data_size))
    buf.write(b'WAVE')
    # fmt chunk
    buf.write(b'fmt ')
    buf.write(struct.pack('<I', 16))  # chunk size
    buf.write(struct.pack('<H', 1))   # PCM
    buf.write(struct.pack('<H', 1))   # mono
    buf.write(struct.pack('<I', SR))  # sample rate
    buf.write(struct.pack('<I', SR * 2))  # byte rate
    buf.write(struct.pack('<H', 2))   # block align
    buf.write(struct.pack('<H', 16))  # bits per sample
    # data chunk
    buf.write(b'data')
    buf.write(struct.pack('<I', data_size))
    for s in audio:
        buf.write(struct.pack('<h', int(s * 32767)))
    return buf.getvalue()

# Cache w pamieci (generuj raz przy imporcie)
_WAV_CACHE = None

def play_climax_motif():
    global _WAV_CACHE
    try:
        if _WAV_CACHE is None:
            _WAV_CACHE = generate_wav_memory()
        # SND_MEMORY nie wspiera ASYNC, wiec gramy synchronicznie (w watku i tak)
        winsound.PlaySound(_WAV_CACHE, winsound.SND_MEMORY)
    except Exception as e:
        print(f'\033[93m[DEBUG] Muzyka error: {e}\033[0m')

def play_music_thread():
    threading.Thread(target=play_climax_motif, daemon=True).start()

# MUZYKA OD RAZU NA STARCIE!
play_music_thread()

ctypes.windll.kernel32.SetConsoleTitleW('Px Proxy - Copilot CLI - Łukasz Guziczak')

# Sprawdz czy px jest zainstalowany
def check_and_install():
    result = subprocess.run([sys.executable, '-m', 'px', '--help'], capture_output=True)
    if result.returncode == 0:
        return True

    # px nie zainstalowany - sprawdź wersję Pythona
    py_ver = sys.version_info
    if py_ver >= (3, 13):
        print('\033[2J\033[H')
        print('\033[93m[!] Moduł px nie jest zainstalowany.\033[0m')
        print(f'\033[93m[!] Python {py_ver.major}.{py_ver.minor} - brak gotowych wheel dla quickjs.\033[0m\n')
        print('\033[96mOpcje:\033[0m')
        print('  1. Zainstaluj Visual C++ Build Tools:')
        print('     https://visualstudio.microsoft.com/visual-cpp-build-tools/')
        print('     (zaznacz "Desktop development with C++")')
        print('')
        print('  2. Użyj Python 3.12 (zalecane)')
        print('')
        choice = input('\033[93mSpróbować instalacji mimo to? (t/n): \033[0m').strip().lower()
        if choice != 't':
            return False

    # Instaluj px-proxy
    print('\033[2J\033[H')
    print('\033[93m[!] Moduł px nie jest zainstalowany.\033[0m')
    print('\033[96m    Instaluję automatycznie...\033[0m\n')
    r = subprocess.run('pip install px-proxy', shell=True)
    if r.returncode == 0:
        print(f'\n\033[92m[OK] px-proxy zainstalowany pomyślnie!\033[0m\n')
        time.sleep(1)
        return True
    else:
        print('\n\033[91m[X] Błąd instalacji px-proxy\033[0m')
        if py_ver >= (3, 13):
            print('\033[93mPrawdopodobnie brak Visual C++ Build Tools.\033[0m')
            print('Pobierz: https://visualstudio.microsoft.com/visual-cpp-build-tools/')
        input('\nNaciśnij Enter aby zamknąć...')
        return False

if not check_and_install():
    sys.exit(1)

Y='\033[93m';C='\033[96m';M='\033[95m';G='\033[92m';W='\033[97m';R='\033[0m';B='\033[94m';RED='\033[91m';O='\033[38;5;208m'
RAINBOW=[RED,O,Y,G,C,B,M]

def rainbow_char(char,idx):
    return f'{RAINBOW[idx%len(RAINBOW)]}{char}{R}'

# Okragla sfera (7 linii) - orbita jednokierunkowa (lewa->prawa, potem znow z lewej)
ball=[
["      .@* * * .      ","   *  *  *  *  *  *  ","  *  *  *  *  *  *  *"," *  *  *  *  *  *  * ","  *  *  *  *  *  *  *","   *  *  *  *  *  *  ","      . * * * .      "],
["      . @* * .       ","   *  o*  *  *  *  * ","  *  *  *  *  *  *  *"," *  *  *  *  *  *  * ","  *  *  *  *  *  *  *","   *  *  *  *  *  *  ","      . * * * .      "],
["      . * @* .       ","   *  * o*  *  *  *  ","  *  o*  *  *  *  *  "," *  *  *  *  *  *  * ","  *  *  *  *  *  *  *","   *  *  *  *  *  *  ","      . * * * .      "],
["      . * * @.       ","   *  *  *o *  *  *  ","  *  * o*  *  *  *  *"," *  o*  *  *  *  *  *","  *  *  *  *  *  *  *","   *  *  *  *  *  *  ","      . * * * .      "],
["      . * * * @      ","   *  *  *  o*  *  * ","  *  *  *o *  *  *  *"," *  * o*  *  *  *  * ","  *  o*  *  *  *  *  ","   *  *  *  *  *  *  ","      . * * * .      "],
["      . * * *  @     ","   *  *  *  * o*  *  ","  *  *  *  o*  *  *  "," *  *  *o *  *  *  * ","  *  * o*  *  *  *  *","   *  o*  *  *  *  * ","      . * * * .      "],
["      . * * *   @    ","   *  *  *  *  o*  * ","  *  *  *  * o*  *  *"," *  *  *  o*  *  *  *","  *  *  *o *  *  *  *","   *  * o*  *  *  *  ","      .o* * * .      "],
["      . * * *    @   ","   *  *  *  *  * o*  ","  *  *  *  *  o*  *  "," *  *  *  * o*  *  * ","  *  *  *  o*  *  *  ","   *  *  *o *  *  *  ","      . o* * * .     "],
["      . * * *     @  ","   *  *  *  *  *  o* ","  *  *  *  *  * o*  *"," *  *  *  *  o*  *  *","  *  *  *  * o*  *  *","   *  *  *  o*  *  * ","      . * o* * .     "],
["      . * * *      @ ","   *  *  *  *  *  *o ","  *  *  *  *  *  o*  "," *  *  *  *  * o*  * ","  *  *  *  *  o*  *  ","   *  *  *  * o*  *  ","      . * * o* .     "],
["      . * * *       @","   *  *  *  *  *  * o","  *  *  *  *  *  *o  "," *  *  *  *  *  o*  *","  *  *  *  *  * o*  *","   *  *  *  *  o*  * ","      . * * * o.     "],
["      . * * *        ","   *  *  *  *  *  *  ","  *  *  *  *  *  * o "," *  *  *  *  *  *o  *","  *  *  *  *  *  o*  ","   *  *  *  *  * o*  ","      . * * *  o     "],
["      . * * *        ","   *  *  *  *  *  *  ","  *  *  *  *  *  *   "," *  *  *  *  *  * o *","  *  *  *  *  *  *o  ","   *  *  *  *  *  o* ","      . * * *   o    "],
["      . * * *        ","   *  *  *  *  *  *  ","  *  *  *  *  *  *   "," *  *  *  *  *  *   *","  *  *  *  *  *  * o ","   *  *  *  *  *  *o ","      . * * *    o   "],
["      . * * *        ","   *  *  *  *  *  *  ","  *  *  *  *  *  *   "," *  *  *  *  *  *   *","  *  *  *  *  *  *   ","   *  *  *  *  *  * o","      . * * *     o  "]
]

fireworks=[
["",
"            {Y}*{R}",
"       {M}*{R}    {W}|{R}    {C}*{R}",
"    {G}*{R}    {W}\\{R}  {Y}|{R}  {W}/{R}    {Y}*{R}",
"         {C}*{R}{M}-{RED}@{M}-{R}{Y}*{R}",
"    {M}*{R}    {W}/{R}  {Y}|{R}  {W}\\{R}    {G}*{R}",
"       {C}*{R}    {W}|{R}    {M}*{R}",
"            {G}*{R}",""],
["",
"      {RED}*{R}         {O}*{R}         {Y}*{R}",
"   {M}*{R}    {W}* * *{R}    {C}*{R}    {W}* * *{R}    {G}*{R}",
"       {Y}*{R} {G}@{R} {Y}*{R}         {M}*{R} {C}@{R} {M}*{R}",
"   {G}*{R}    {W}* * *{R}    {Y}*{R}    {W}* * *{R}    {M}*{R}",
"      {C}*{R}         {M}*{R}         {G}*{R}",""],
["",
"         {Y}* * * * *{R}",
"      {M}*{R}    {W}* * *{R}    {C}*{R}",
"   {G}*{R}    {Y}*{R}  {RED}@{R}  {Y}*{R}    {M}*{R}",
"      {C}*{R}    {W}* * *{R}    {Y}*{R}",
"         {G}* * * * *{R}",""],
["",
"   {RED}*{R}  {O}*{R}  {Y}*{R}  {G}*{R}  {C}*{R}  {B}*{R}  {M}*{R}",
"      {Y}*{R}  {G}*{R}  {C}*{R}  {M}*{R}  {RED}*{R}",
"   {M}*{R}  {RED}*{R}  {O}*{R}  {Y}*{R}  {G}*{R}  {C}*{R}  {B}*{R}",
"      {C}*{R}  {B}*{R}  {M}*{R}  {RED}*{R}  {O}*{R}",
"   {G}*{R}  {C}*{R}  {B}*{R}  {M}*{R}  {RED}*{R}  {O}*{R}  {Y}*{R}",""],
["",
"      {RED}*{R}{O}*{R}{Y}*{R}{G}*{R}{C}*{R}{B}*{R}{M}*{R}",
"    {M}*{R}    {W}BOOM!{R}    {RED}*{R}",
"   {B}*{R}      {Y}*{R}       {O}*{R}",
"    {C}*{R}             {Y}*{R}",
"      {G}*{R}{C}*{R}{B}*{R}{M}*{R}{RED}*{R}{O}*{R}{Y}*{R}",""]
]

wishes=['Łukaszu, miłego dnia! <3','Łukaszu, powodzenia z kodem!','Łukaszu, niech Ci się wiedzie!','Łukaszu, dziś będzie super!','Łukaszu, kod sam się napisze!','Łukaszu, bądź kreatywny!','Łukaszu, jesteś wspaniały!','Łukaszu, wszystko się uda!','Łukaszu, jesteś mistrzem!']

def color_ball_line(line, frame_idx):
    """Koloruje linie kuli z efektem rainbow dla gwiazdek"""
    result = ''
    star_idx = 0
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '@':
            result += f'{RED}@{R}'
        elif ch == 'o':
            result += f'{O}o{R}'
        elif ch == '*':
            result += f'{RAINBOW[(star_idx + frame_idx) % len(RAINBOW)]}*{R}'
            star_idx += 1
        elif ch == '.':
            result += f'{C}.{R}'
        else:
            result += ch
        i += 1
    return result

def clear_animation_area():
    """Czysci obszar animacji - zapobiega bugom przy przejsciu"""
    print('\033[8;0H')
    for _ in range(10):
        print(' ' * 50)

proc = None

def cleanup():
    """Czyszczenie przy wyjsciu"""
    global proc
    if proc:
        try:
            proc.terminate()
            proc.wait(timeout=2)
        except:
            try:
                proc.kill()
            except:
                pass
    print(f'\n{Y}[!] Przerwano (Ctrl+C){R}')
    print(f'{C}Do zobaczenia!{R}\n')

try:
    print('\033[2J\033[H')
    print(f'{Y}+======================================+{R}')
    print(f'{Y}|{R}                                      {Y}|{R}')
    print(f'{Y}|{R}   {W}* Proxy dla Copilot CLI *{R}          {Y}|{R}')
    print(f'{Y}|{R}   {C}Łukasz Guziczak{R}                    {Y}|{R}')
    print(f'{Y}|{R}                                      {Y}|{R}')
    print(f'{Y}+======================================+{R}')
    print()

    proc=subprocess.Popen([sys.executable,'-m','px'])

    # Animowana kula - 3 pelne obroty z rainbow effect
    for rotation in range(3):
        for frame_idx, frame in enumerate(ball):
            print('\033[8;0H')
            for line in frame:
                colored = color_ball_line(line, frame_idx + rotation * len(ball))
                print(f'  {colored}')
            spinners = ['|', '/', '-', '\\']
            spin_colors = [Y, G, C, M]
            sp_idx = (rotation * len(ball) + frame_idx) % 4
            print(f'\n      {spin_colors[sp_idx]}{spinners[sp_idx]} Uruchamiam proxy...{R}')
            time.sleep(0.07)

    # WAZNE: Czyscimy przed fajerwerkami
    clear_animation_area()

    # Fajerwerki - 3 rundy
    for rnd in range(3):
        for frame in fireworks:
            print('\033[8;0H')
            for line in frame:
                ln = line.format(Y=Y, C=C, M=M, G=G, W=W, R=R, RED=RED, B=B, O=O)
                print(f'  {ln}')
            print()
            time.sleep(0.18)

    # Finalowy pokaz
    clear_animation_area()
    print('\033[8;0H')
    print(f'''
   {RED}*{R}  {O}*{R}  {Y}*{R}  {G}*{R}  {C}*{R}  {B}*{R}  {M}*{R}  {RED}*{R}
      {Y}*{R}  {G}*{R}  {C}*{R}  {M}*{R}  {RED}*{R}  {O}*{R}
   {M}*{R}  {RED}*{R}  {O}*{R}  {Y}*{R}  {G}*{R}  {C}*{R}  {B}*{R}  {M}*{R}
      {C}*{R}  {B}*{R}  {M}*{R}  {RED}*{R}  {O}*{R}  {Y}*{R}
   {G}*{R}  {C}*{R}  {B}*{R}  {M}*{R}  {RED}*{R}  {O}*{R}  {Y}*{R}  {G}*{R}
''')
    print()

    # Spadajace GOTOWE jak sopelki - literka po literce
    gotowe_txt = "~*~*~*~  GOTOWE!  ~*~*~*~"
    final_row = 15
    start_row = 8
    col_start = 6

    # Kazda litera spada osobno
    letter_positions = [start_row] * len(gotowe_txt)
    letter_done = [False] * len(gotowe_txt)

    # Animacja spadania
    while not all(letter_done):
        for row in range(start_row, final_row + 1):
            print(f'\033[{row};{col_start}H' + ' ' * (len(gotowe_txt) + 2))
        available = [i for i, done in enumerate(letter_done) if not done]
        if available:
            for _ in range(min(3, len(available))):
                if available:
                    idx = random.choice(available)
                    available.remove(idx)
                    if letter_positions[idx] < final_row:
                        letter_positions[idx] += 1
                    else:
                        letter_done[idx] = True
        for i, char in enumerate(gotowe_txt):
            if char != ' ':
                row = letter_positions[i]
                col = col_start + i
                colored = rainbow_char(char, i + letter_positions[i])
                print(f'\033[{row};{col}H{colored}')
        time.sleep(0.04)

    # Koncowa animacja rainbow na miejscu
    for wave in range(12):
        rainbow_gotowe = ''.join(rainbow_char(c, idx + wave) if c not in ' ' else ' ' for idx, c in enumerate(gotowe_txt))
        print(f'\033[{final_row};{col_start}H{rainbow_gotowe}')
        time.sleep(0.08)
    print()
    time.sleep(0.3)

    wish = random.choice(wishes)
    for i in range(len(wish) + 1):
        stars = ''.join(rainbow_char('*', j) for j in range(3))
        print(f'\r   {stars} {W}{wish[:i]}{R}', end='', flush=True)
        time.sleep(0.03)
    stars_end = ''.join(rainbow_char('*', j + 4) for j in range(3))
    print(f' {stars_end}')
    print()
    time.sleep(2)

    for i in range(3, 0, -1):
        dots = '.' * (4 - i)
        spinners = ['|', '/', '-', '\\']
        print(f'\r   {C}{spinners[i % 4]} Minimalizuje za {i}{dots}{R}   ', end='', flush=True)
        time.sleep(1)
    print(f'\r   {G}[OK] Zminimalizowano!{R}          ')
    time.sleep(0.3)

    # Minimalizacja na pasek - napraw style okna
    hwnd = ctypes.windll.kernel32.GetConsoleWindow()
    if hwnd:
        GWL_STYLE = -16
        GWL_EXSTYLE = -20
        WS_MINIMIZEBOX = 0x00020000
        WS_CAPTION = 0x00C00000
        WS_SYSMENU = 0x00080000
        WS_EX_APPWINDOW = 0x00040000
        WS_EX_TOOLWINDOW = 0x00000080

        # Napraw zwykly styl
        style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_STYLE)
        new_style = style | WS_MINIMIZEBOX | WS_CAPTION | WS_SYSMENU
        ctypes.windll.user32.SetWindowLongW(hwnd, GWL_STYLE, new_style)

        # Napraw extended styl - dodaj APPWINDOW, usun TOOLWINDOW
        ex_style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
        new_ex_style = (ex_style | WS_EX_APPWINDOW) & ~WS_EX_TOOLWINDOW
        ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, new_ex_style)

        # Odswiez okno
        SWP_FRAMECHANGED = 0x0020
        SWP_NOMOVE = 0x0002
        SWP_NOSIZE = 0x0001
        SWP_NOZORDER = 0x0004
        ctypes.windll.user32.SetWindowPos(hwnd, 0, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER)

        # Minimalizuj
        ctypes.windll.user32.ShowWindow(hwnd, 6)  # SW_MINIMIZE

    print()
    print(f'{C}=== Px Proxy AKTYWNE ==={R}')
    print()
    exit_code = proc.wait()

    if exit_code != 0:
        print(f'\n{RED}[!] Px zakończył się z kodem: {exit_code}{R}')
    print(f'\n{Y}Naciśnij Enter aby zamknąć...{R}')
    input()

except KeyboardInterrupt:
    cleanup()
except Exception as e:
    print(f'\n{RED}[!] Błąd: {e}{R}')
    cleanup()
BAT = r"""
:python
@chcp 65001 >nul
@where python >nul 2>&1 || (
    echo [!] Python nie jest zainstalowany!
    echo     Pobierz z: https://www.python.org/downloads/
    echo.
    pause
    exit /b 1
)
@python -x "%~f0" %*
@exit /b
"""
