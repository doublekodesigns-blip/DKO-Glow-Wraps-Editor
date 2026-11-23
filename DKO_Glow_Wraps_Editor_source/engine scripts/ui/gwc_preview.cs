// Live preview for DKO Glow Wraps Colors: draws the straps with the moving glow, the way the add-on builds it.
// preview.dat holds, per version / view / strap layout, the strap texture position (u, v) of every pixel.
// The glow picture is made here exactly like the engine makes it (band shapes, Melt drips, Wavy waves, Two-tone,
// Repeat drawn in) and moved like the game material moves it. Lighting and brightness are only approximate.
// (C# 5: compiled by Windows PowerShell 5.1.)
using System;
using System.IO;
using System.IO.Compression;

public static class GwcPreview
{
    public static int W, H;
    static byte[][] shade;          // [ver * 2 + view]
    static ushort[][] mapU, mapV;   // [(ver * 2 + view) * 4 + layout]
    static float[] pic;             // rows * pw * 4 (r, g, b, a), in picture order (row 0 = v 0)
    static int rows = 1, pw = 1, reps = 1;
    static int ver, lay;
    static double br, bg, bb, gr, gg, gb, ev = 1.5, spd, spec, specPow, diffuse;
    static bool twoTone, wide;

    static readonly double[] MeltLen = { 0.37, 0.93, 0.55, 1.0, 0.45, 0.78, 0.30, 0.88, 0.62, 0.41, 0.97, 0.52 };
    const int MeltDrips = 12;

    public static string Load(string path)
    {
        try
        {
            byte[] raw;
            using (var fs = File.OpenRead(path))
            using (var gz = new GZipStream(fs, CompressionMode.Decompress))
            using (var ms = new MemoryStream())
            {
                gz.CopyTo(ms);
                raw = ms.ToArray();
            }
            if (raw[0] != 'G' || raw[1] != 'W' || raw[2] != 'C' || raw[3] != 'P') return "not a preview file";
            W = BitConverter.ToUInt16(raw, 4);
            H = BitConverter.ToUInt16(raw, 6);
            int n = W * H, p = 8;
            shade = new byte[4][];
            mapU = new ushort[16][];
            mapV = new ushort[16][];
            for (int sv = 0; sv < 4; sv++)
            {
                shade[sv] = new byte[n];
                Buffer.BlockCopy(raw, p, shade[sv], 0, n); p += n;
                for (int l = 0; l < 4; l++)
                {
                    mapU[sv * 4 + l] = new ushort[n];
                    Buffer.BlockCopy(raw, p, mapU[sv * 4 + l], 0, 2 * n); p += 2 * n;
                    mapV[sv * 4 + l] = new ushort[n];
                    Buffer.BlockCopy(raw, p, mapV[sv * 4 + l], 0, 2 * n); p += 2 * n;
                }
            }
            return "";
        }
        catch (Exception e) { return e.Message; }
    }

    public static bool Ready { get { return shade != null; } }
    public static float[] Picture { get { return pic; } }
    public static int PictureRows { get { return rows; } }
    public static int PictureWidth { get { return pw; } }

    // ---- the glow band, as the engine draws it (dko_item.band_profile / melt_value) ----
    static double Clamp01(double x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }
    static double Frac(double x) { return x - Math.Floor(x); }

    // returns alpha; col = color 0..1 (only changed for Two-tone)
    static double BandProfile(double v, string style, double width, double[] g, double[] t, bool tailUp, double[] col)
    {
        width = Math.Max(0.1, width);
        if (style == "bands") v = (Math.Floor(v * 24) + 0.5) / 24;
        double a, d;
        col[0] = col[1] = col[2] = 1.0;
        if (t != null)
        {
            double head = tailUp ? 0.35 : 0.65;
            double off = tailUp ? (v - head) : (head - v);
            double k;
            if (off < 0) { k = 0; a = Math.Pow(Math.Max(0.0, 1.0 + off / (0.05 * width)), 1.5); }
            else { k = Math.Min(1.0, off / (0.22 * width)); a = Math.Pow(Math.Max(0.0, 1.0 - off / Math.Min(0.62, 0.5 * width)), 1.3); }
            for (int i = 0; i < 3; i++) col[i] = g[i] * (1 - k) + t[i] * k;
            d = Math.Abs(off) / (0.5 * width);
        }
        else
        {
            d = Math.Abs(v - 0.5) / (0.18 * width);
            a = Math.Pow(Math.Max(0.0, 1.0 - d), 1.5);
        }
        if (style == "rings")
        {
            if (t == null)
            {
                double span = 0.135 * width;
                a = 0;
                for (int i = -1; i <= 1; i++)
                {
                    double r = Math.Max(0.0, 1.0 - Math.Abs(v - (0.5 + i * span)) / (0.035 * width)) * (i == 0 ? 1.0 : 0.7);
                    if (r > a) a = r;
                }
            }
            else
            {
                int sg = tailUp ? 1 : -1;
                double head = tailUp ? 0.35 : 0.65;
                double[] fs = { 1.0, 0.75, 0.5 };
                a = 0;
                for (int i = 0; i < 3; i++)
                {
                    double ctr = head + sg * i * 0.12 * width;
                    double r = Math.Max(0.0, 1.0 - Math.Abs(v - ctr) / (0.035 * width)) * fs[i];
                    if (r > a)
                    {
                        a = r;
                        double k = Math.Min(1.0, i / 2.0);
                        for (int j = 0; j < 3; j++) col[j] = g[j] * (1 - k) + t[j] * k;
                    }
                }
            }
        }
        else if (style == "sharp")
        {
            a = a > 0.3 ? 1.0 : 0.0;
        }
        return a;
    }

    static double Melt(double v, double x01, double width)
    {
        int i = ((int)Math.Floor(x01 * MeltDrips)) % MeltDrips;
        double x = Frac(x01 * MeltDrips) - 0.5;
        double top = 0.5 - 0.03 * width * (0.5 + MeltLen[(i + 5) % MeltDrips]);
        double off = v - top;
        if (off < 0) return 0;
        double L = (0.08 + 0.22 * MeltLen[i]) * width;
        double k = off / L;
        if (k >= 1.0) return 0;
        double half = 0.30 * (1.0 - 0.6 * k);
        double hd = 0.03 * width;
        if (off < hd) half *= Math.Sqrt(Math.Max(0.0, 1.0 - Math.Pow((hd - off) / hd, 2)));
        if (k > 0.85) half *= Math.Sqrt(Math.Max(0.0, 1.0 - Math.Pow((k - 0.85) / 0.15, 2)));
        if (Math.Abs(x) >= half) return 0;
        double edge = Math.Min(1.0, (half - Math.Abs(x)) / 0.06);
        return 0.95 * edge * (1.0 - 0.35 * k);
    }

    // version 0 sfw / 1 nsfw; layout 0 v / 1 c / 2 wv / 3 wc; colors 0..255; glow2 r < 0 = none; sign +1 / -1
    public static void Set(int version, int layout, int baseR, int baseG, int baseB, int glowR, int glowG, int glowB,
                           int g2R, int g2G, int g2B, string finish, double glowEv, double speed, int sign, int repeat,
                           string band, double width)
    {
        ver = Math.Max(0, Math.Min(1, version));
        lay = Math.Max(0, Math.Min(3, layout));
        br = baseR / 255.0; bg = baseG / 255.0; bb = baseB / 255.0;
        gr = glowR / 255.0; gg = glowG / 255.0; gb = glowB / 255.0;
        ev = glowEv;
        twoTone = g2R >= 0;
        string st = band ?? "original";
        wide = (st == "wavy" || st == "melt");
        width = Math.Max(0.25, Math.Min(2.5, width));
        int rep = Math.Max(1, Math.Min(8, repeat));
        reps = rep * (wide ? 3 : 1);
        spd = sign * Math.Abs(speed) / reps;
        switch (finish)
        {
            case "chrome": diffuse = 0.45; spec = 0.85; specPow = 18; break;
            case "metallic": diffuse = 0.75; spec = 0.45; specPow = 10; break;
            case "satin": diffuse = 0.85; spec = 0.22; specPow = 5; break;
            case "gloss": diffuse = 0.9; spec = 0.5; specPow = 24; break;
            default: diffuse = 1.0; spec = 0.0; specPow = 1; break;
        }
        string style = (st == "soft" || st == "wavy") ? "original" : st;
        bool tailUp = sign > 0;
        double[] g = { gr, gg, gb };
        double[] t = twoTone ? new double[] { g2R / 255.0, g2G / 255.0, g2B / 255.0 } : null;
        pw = wide ? 64 : 1;
        rows = Math.Min(2048, 128 * reps);
        pic = new float[rows * pw * 4];
        double[] col = new double[3];
        for (int y = 0; y < rows; y++)
        {
            double v = Frac((y + 0.5) / rows * reps);
            for (int x = 0; x < pw; x++)
            {
                double a;
                col[0] = col[1] = col[2] = 1;
                if (st == "melt")
                {
                    a = Melt(v, (x + 0.5) / pw, width);
                    if (twoTone)
                    {
                        double k = Clamp01((v - 0.5) / (0.3 * width));
                        for (int i = 0; i < 3; i++) col[i] = g[i] * (1 - k) + t[i] * k;
                    }
                }
                else
                {
                    double vv = v;
                    if (st == "wavy") vv = Frac(v - 0.22 * Math.Sin(2 * Math.PI * 4 * (x + 0.5) / pw));
                    a = BandProfile(vv, style, width, g, t, tailUp, col);
                }
                if (!twoTone) { col[0] = gr; col[1] = gg; col[2] = gb; }
                int o = (y * pw + x) * 4;
                pic[o] = (float)col[0]; pic[o + 1] = (float)col[1]; pic[o + 2] = (float)col[2]; pic[o + 3] = (float)a;
            }
        }
    }

    // one frame: view 0 front / 1 back, time in seconds; argb = W * H pixels; bgArgb for empty pixels
    public static void Render(int view, double time, int[] argb, int bgArgb)
    {
        if (shade == null || pic == null) return;
        int sv = ver * 2 + Math.Max(0, Math.Min(1, view));
        byte[] sh = shade[sv];
        ushort[] mu = mapU[sv * 4 + lay], mv = mapV[sv * 4 + lay];
        double whiten = Clamp01((ev - 1.25) / 3.0) * 0.85;      // high Glow = white-hot
        double gain = 0.55 + 0.3 * Math.Min(ev, 3.0);
        int n = W * H;
        for (int i = 0; i < n; i++)
        {
            byte s = sh[i];
            if (s == 0) { argb[i] = bgArgb; continue; }
            double l = s / 255.0;
            double u = mu[i] / 65535.0, v = mv[i] / 65535.0;
            // the game reads the picture upside down; the glow moves by v - time * speed
            double vp = 1.0 - Frac(v - time * spd);
            int yy = (int)(vp * rows); if (yy >= rows) yy = rows - 1; if (yy < 0) yy = 0;
            int xx = wide ? (int)(Frac(u) * pw) : 0; if (xx >= pw) xx = pw - 1;
            int o = (yy * pw + xx) * 4;
            double a = pic[o + 3] * gain;
            if (a > 1) a = 1;
            double hl = spec * Math.Pow(l, specPow);
            double r = br * l * diffuse + hl, g = bg * l * diffuse + hl, b = bb * l * diffuse + hl;
            double cr = pic[o] + (1 - pic[o]) * whiten, cg = pic[o + 1] + (1 - pic[o + 1]) * whiten, cb = pic[o + 2] + (1 - pic[o + 2]) * whiten;
            r = r * (1 - a) + cr * a; g = g * (1 - a) + cg * a; b = b * (1 - a) + cb * a;
            int R = (int)(Clamp01(r) * 255), G = (int)(Clamp01(g) * 255), B = (int)(Clamp01(b) * 255);
            argb[i] = unchecked((int)0xFF000000) | (R << 16) | (G << 8) | B;
        }
    }
}
