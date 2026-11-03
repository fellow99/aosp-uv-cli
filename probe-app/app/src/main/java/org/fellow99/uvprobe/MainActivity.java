package org.fellow99.uvprobe;

import android.app.Activity;
import android.os.Bundle;
import android.widget.LinearLayout;
import android.widget.Button;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileWriter;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * uv-cli 探针载体（003-cli App 域探针，FR-003-050~055 / tasks T11；TC-003-20~27）。
 *
 * 职责（镜像 docs/000-工程规划.md §3 消费方环境引导层 + §7 环境变量契约的 App 域实例化）：
 *  1) exec：ProcessBuilder 启动 nativeLibraryDir/libuv_cli.so（D1：useLegacyPackaging 物理落盘；
 *     untrusted_app SELinux 域 exec = 消费方真实形态，adb shell 域覆盖不到的判据在此验证）；
 *  2) 注入：UV_CACHE_DIR / HOME / TMPDIR / PATH（规划 §7 表的 App 域实例化；SSL_CERT_FILE 永不注入，D4）；
 *  3) 判据：TC-003-20…27 逐条 PASS/FAIL + JSON 报告落盘 filesDir/probe-report-app.json；
 *  4) 启动即后台线程自动全量运行（FR-003-055，无交互依赖；UI 同步显示日志）。
 */
public class MainActivity extends Activity {

    private TextView logView;
    private String nativeDir;   // applicationInfo.nativeLibraryDir（D1 落盘点）
    private String uvExe;       // nativeDir/libuv_cli.so
    private File filesDir;
    private final StringBuilder uiLog = new StringBuilder();
    private final List<JSONObject> probes = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        nativeDir = getApplicationInfo().nativeLibraryDir;
        uvExe = nativeDir + "/libuv_cli.so";
        filesDir = getFilesDir();

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        Button run = new Button(this);
        run.setText("RE-RUN ALL PROBES");
        run.setOnClickListener(v -> runAll());
        ScrollView scroll = new ScrollView(this);
        logView = new TextView(this);
        logView.setTypeface(android.graphics.Typeface.MONOSPACE);
        logView.setTextIsSelectable(true);
        logView.setTextSize(11f);
        int pad = (int) (getResources().getDisplayMetrics().density * 8);
        logView.setPadding(pad, pad, pad, pad);
        scroll.addView(logView);
        root.addView(run, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        root.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(root);
        log("uv-cli probe-app ready\nnativeDir=" + nativeDir
                + "\nfilesDir=" + filesDir
                + "\n启动自动执行 App 域探针（TC-003-20~27）…");
        runAll();
    }

    private void log(String s) {
        runOnUiThread(() -> {
            uiLog.append(s).append('\n');
            logView.setText(uiLog.toString());
        });
    }

    /** 单进程执行：cmd = 完整 argv（argv[0] 为 uvExe）；env 覆盖项由注入表构造。返回 {rc,out,err,ms}。 */
    private Map<String, Object> exec(List<String> cmd, Map<String, String> envOverride) {
        Map<String, Object> r = new LinkedHashMap<>();
        long t0 = System.currentTimeMillis();
        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.directory(filesDir);
            Map<String, String> e = pb.environment();
            // 基础注入（规划 §7 App 域实例化；SSL_CERT_FILE 永不注入，D4）
            e.put("PATH", nativeDir + ":/system/bin");
            e.put("HOME", new File(filesDir, "home").getAbsolutePath());
            e.put("TMPDIR", new File(filesDir, "tmp").getAbsolutePath());
            e.put("UV_CACHE_DIR", new File(filesDir, "uv/cache").getAbsolutePath());
            e.put("UV_HTTP_TIMEOUT", "30");
            if (envOverride != null) for (Map.Entry<String, String> kv : envOverride.entrySet()) {
                if (kv.getValue() == null) e.remove(kv.getKey()); else e.put(kv.getKey(), kv.getValue());
            }
            Process p = pb.start();
            StringBuilder out = new StringBuilder();
            StringBuilder err = new StringBuilder();
            Thread to = new Thread(() -> read(p.getInputStream(), out));
            Thread te = new Thread(() -> read(p.getErrorStream(), err));
            to.start(); te.start();
            boolean finished = p.waitFor(60, TimeUnit.SECONDS);
            if (!finished) { p.destroyForcibly(); r.put("rc", -1); r.put("out", ""); r.put("err", "timeout(60s)"); }
            else {
                to.join(2000); te.join(2000);
                r.put("rc", p.exitValue());
                r.put("out", out.toString());
                r.put("err", err.toString());
            }
        } catch (Exception ex) {
            r.put("rc", -2);
            r.put("out", "");
            r.put("err", "exec-failed: " + ex.getClass().getSimpleName() + ": " + ex.getMessage());
        }
        r.put("ms", System.currentTimeMillis() - t0);
        return r;
    }

    private static void read(java.io.InputStream is, StringBuilder sb) {
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append('\n');
        } catch (Exception ignored) { }
    }

    private void record(String id, String title, boolean pass, Map<String, Object> ex, String detail) {
        JSONObject o = new JSONObject();
        try {
            o.put("id", id);
            o.put("title", title);
            o.put("verdict", pass ? "PASS" : "FAIL");
            o.put("exit", ex == null ? null : ex.get("rc"));
            o.put("ms", ex == null ? 0 : ex.get("ms"));
            o.put("stdout", ex == null ? "" : trim((String) ex.get("out")));
            o.put("stderr", ex == null ? "" : trim((String) ex.get("err")));
            o.put("detail", detail == null ? "" : detail);
        } catch (Exception ignored) { }
        probes.add(o);
        log(String.format("%-12s %-5s %s%s", id, pass ? "PASS" : "FAIL", title,
                (detail == null || detail.isEmpty()) ? "" : "（" + detail + "）"));
    }

    private static String trim(String s) {
        if (s == null) return "";
        s = s.replace("\r", "").replace("\n", " ");
        return s.length() > 300 ? s.substring(0, 300) : s;
    }

    private void runAll() {
        probes.clear();
        uiLog.setLength(0);
        new Thread(() -> {
            // ── TC-003-20 环境快照（FR-003-050 判据：nativeDir 落盘 + 可执行位）────
            File soFile = new File(uvExe);
            JSONObject snap = new JSONObject();
            try {
                snap.put("nativeDir", nativeDir);
                snap.put("soExists", soFile.exists());
                snap.put("soExecutable", soFile.canExecute());
                snap.put("soLength", soFile.length());
                snap.put("filesDir", filesDir.getAbsolutePath());
                Map<String, Object> idz = exec(list("/system/bin/id", "-Z"), null);
                snap.put("selinuxContext", trim((String) idz.get("out")));
            } catch (Exception ignored) { }
            log("snapshot: " + snap);
            boolean d1ok = soFile.exists() && soFile.canExecute();
            record("TC-003-20", "App 域环境快照 + D1 落盘", d1ok, null,
                    d1ok ? "libuv_cli.so 落 nativeLibraryDir 且可执行" : "nativeDir 缺制品或不可执行");

            if (!d1ok) { writeReport(); return; }

            List<String> version = new ArrayList<>();
            version.add(uvExe); version.add("--version");

            // ── TC-003-21 App 域版本回程（P1 等价；FR-003-051：untrusted_app 域 exec）──
            Map<String, Object> r21 = exec(version, null);
            String out21 = ((String) r21.get("out")).trim();
            record("TC-003-21", "App 域版本回程（P1）", (Integer) r21.get("rc") == 0 && out21.startsWith("uv 0.13.6"),
                    r21, out21.isEmpty() ? "无输出（SELinux 拒绝？看 stderr）" : out21);

            // ── TC-003-22 filesDir 注入（P5 等价；FR-003-052）──────────────────────
            List<String> cache = new ArrayList<>();
            cache.add(uvExe); cache.add("cache"); cache.add("dir");
            Map<String, Object> r22 = exec(cache, null);
            String expect22 = new File(filesDir, "uv/cache").getAbsolutePath();
            String got22 = ((String) r22.get("out")).trim();
            record("TC-003-22", "filesDir 注入（P5）", (Integer) r22.get("rc") == 0 && got22.equals(expect22),
                    r22, got22.equals(expect22) ? "输出=注入值" : "got=" + got22 + " expect=" + expect22);

            // ── TC-003-23 venv 失败形态（App 域；无解释器语义，D7 组合契约佐证）──────
            List<String> venv = new ArrayList<>();
            venv.add(uvExe); venv.add("venv"); venv.add(new File(filesDir, "venvs/t1").getAbsolutePath());
            Map<String, Object> r23 = exec(venv, null);
            int rc23 = (Integer) r23.get("rc");
            String err23 = ((String) r23.get("err")) + ((String) r23.get("out"));
            boolean p23 = rc23 != 0 && err23.contains("interpreter");
            record("TC-003-23", "venv 失败形态（App 域）", p23, r23,
                    p23 ? "无解释器语义确认（解释器来自 python-cli，D7）" : trim(err23));

            // ── TC-003-24 uv python install 禁用（C2/D7 红线；FR-003-053）──────────
            List<String> pyinstall = new ArrayList<>();
            pyinstall.add(uvExe); pyinstall.add("python"); pyinstall.add("install"); pyinstall.add("3.12");
            Map<String, Object> r24 = exec(pyinstall, null);
            int rc24 = (Integer) r24.get("rc");
            String all24 = ((String) r24.get("err")) + ((String) r24.get("out"));
            boolean p24 = rc24 != 0 && all24.contains("No download found");
            record("TC-003-24", "uv python install 禁用（C2/D7）", p24, r24,
                    p24 ? "上游无 android managed python（红线产品层成立）" : trim(all24));

            // ── TC-003-25 XDG 兜底（App 域）───────────────────────────────────────
            Map<String, String> xdg = new LinkedHashMap<>();
            xdg.put("UV_CACHE_DIR", null);
            xdg.put("XDG_CACHE_HOME", new File(filesDir, "xdg").getAbsolutePath());
            Map<String, Object> r25 = exec(cache, xdg);
            String got25 = ((String) r25.get("out")).trim();
            boolean p25 = (Integer) r25.get("rc") == 0 && got25.startsWith(new File(filesDir, "xdg").getAbsolutePath());
            record("TC-003-25", "XDG 兜底（App 域）", p25, r25, "got=" + got25);

            // ── TC-003-26 退出码采样（App 域）─────────────────────────────────────
            List<String> bogus = new ArrayList<>();
            bogus.add(uvExe); bogus.add("--bogus-flag");
            Map<String, Object> r26a = exec(bogus, null);
            List<String> nosuch = new ArrayList<>();
            nosuch.add(uvExe); nosuch.add("no-such-command");
            Map<String, Object> r26b = exec(nosuch, null);
            boolean p26 = (Integer) r26a.get("rc") == 2 && (Integer) r26b.get("rc") == 2;
            Map<String, Object> both = new LinkedHashMap<>(r26a);
            both.put("out", "a.rc=" + r26a.get("rc") + " b.rc=" + r26b.get("rc"));
            record("TC-003-26", "退出码采样（App 域）", p26, both, "clap 口径预期 2/2");

            // ── TC-003-27 help 直出（App 域）──────────────────────────────────────
            List<String> help = new ArrayList<>();
            help.add(uvExe); help.add("help");
            Map<String, Object> r27 = exec(help, null);
            boolean p27 = (Integer) r27.get("rc") == 0;
            record("TC-003-27", "help 直出（App 域）", p27, r27, "");

            writeReport();
        }, "uv-probe").start();
    }

    private void writeReport() {
        try {
            JSONObject reportJson = new JSONObject();
            reportJson.put("runAt", new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'",
                    java.util.Locale.US).format(new java.util.Date()));
            reportJson.put("artifact", uvExe);
            JSONArray arr = new JSONArray();
            for (JSONObject o : probes) arr.put(o);
            reportJson.put("probes", arr);
            File f = new File(filesDir, "probe-report-app.json");
            try (FileWriter w = new FileWriter(f)) {
                w.write(reportJson.toString(2));
            }
            long npass = 0, nfail = 0;
            for (JSONObject o : probes) {
                if ("PASS".equals(o.optString("verdict"))) npass++; else nfail++;
            }
            log("\n== 汇总：PASS=" + npass + " FAIL=" + nfail
                    + " → " + f.getAbsolutePath() + "（adb shell cat 可回读） ==");
        } catch (Exception ex) {
            log("writeReport failed: " + ex);
        }
    }

    private static List<String> list(String... items) {
        List<String> l = new ArrayList<>();
        for (String i : items) l.add(i);
        return l;
    }
}
