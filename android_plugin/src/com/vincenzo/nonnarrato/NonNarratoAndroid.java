package com.vincenzo.nonnarrato;

// Plugin Android di NonNarrato (Godot, plugin v2).
// Fa le cose che GDScript da solo non può fare bene:
//  - installare l'aggiornamento scaricato da GitHub con una sessione di PackageInstaller,
//    senza conferme quando Android lo permette (aggiornamento di sé stesso, API 31+);
//  - leggere i modi dello schermo e chiederne uno (risoluzione e frequenza);
//  - capire dove va il suono (altoparlante, cuffie, Bluetooth, USB) e se il telefono è silenzioso;
//  - riconoscere il dispositivo: memoria, processore, versione di Android, classe di prestazioni,
//    spazio libero, sensori; e lo stato dell'energia (risparmio energetico, modalità gioco di Android).
// Compilato dalla compilazione su GitHub (strumenti/compila_plugin.sh) e messo in addons/.

import android.app.Activity;
import android.app.ActivityManager;
import android.app.GameManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.content.pm.SigningInfo;
import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.net.Uri;
import android.hardware.Sensor;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.PowerManager;
import android.os.StatFs;
import android.os.Vibrator;
import android.provider.Settings;
import android.view.Display;
import android.view.Window;
import android.view.WindowManager;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

public class NonNarratoAndroid extends GodotPlugin {
	private static final String AZIONE_STATO = "com.vincenzo.nonnarrato.STATO_INSTALLAZIONE";
	private boolean ricevitoreAttivo = false;
	private String ultimoStato = "";

	public NonNarratoAndroid(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "NonNarratoAndroid";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> segnali = new HashSet<>();
		segnali.add(new SignalInfo("stato_installazione", Integer.class, String.class));
		return segnali;
	}

	// ------------------------------------------------------------ installazione

	private final BroadcastReceiver ricevitore = new BroadcastReceiver() {
		@Override
		public void onReceive(Context contesto, Intent intent) {
			int stato = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE);
			String messaggio = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE);
			if (messaggio == null) {
				messaggio = "";
			}
			if (stato == PackageInstaller.STATUS_PENDING_USER_ACTION) {
				// Android vuole una conferma (per esempio la prima volta): mostro la sua finestra.
				Intent conferma;
				if (Build.VERSION.SDK_INT >= 33) {
					conferma = intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent.class);
				} else {
					conferma = intent.getParcelableExtra(Intent.EXTRA_INTENT);
				}
				Activity attivita = getActivity();
				if (conferma != null && attivita != null) {
					conferma.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
					try {
						attivita.startActivity(conferma);
					} catch (Exception e) {
						messaggio = "conferma non aperta: " + e;
					}
				}
			}
			ultimoStato = stato + " " + messaggio;
			emitSignal("stato_installazione", Integer.valueOf(stato), messaggio);
		}
	};

	@UsedByGodot
	public int livelloApi() {
		return Build.VERSION.SDK_INT;
	}

	@UsedByGodot
	public boolean puoInstallare() {
		Activity attivita = getActivity();
		if (attivita == null) {
			return false;
		}
		if (Build.VERSION.SDK_INT < 26) {
			return true;
		}
		return attivita.getPackageManager().canRequestPackageInstalls();
	}

	@UsedByGodot
	public void apriPermessoInstallazione() {
		Activity attivita = getActivity();
		if (attivita == null || Build.VERSION.SDK_INT < 26) {
			return;
		}
		Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
				Uri.parse("package:" + attivita.getPackageName()));
		intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		try {
			attivita.startActivity(intent);
		} catch (Exception e) {
			ultimoStato = "impostazioni non aperte: " + e;
		}
	}

	@UsedByGodot
	public String installatore() {
		// Chi risulta aver installato il gioco: serve a capire se l'aggiornamento sarà senza conferme.
		Activity attivita = getActivity();
		if (attivita == null) {
			return "";
		}
		try {
			PackageManager pm = attivita.getPackageManager();
			if (Build.VERSION.SDK_INT >= 30) {
				String chi = pm.getInstallSourceInfo(attivita.getPackageName()).getInstallingPackageName();
				return chi == null ? "nessuno" : chi;
			}
			String chi = pm.getInstallerPackageName(attivita.getPackageName());
			return chi == null ? "nessuno" : chi;
		} catch (Exception e) {
			return "errore: " + e;
		}
	}

	@UsedByGodot
	public String ultimoStato() {
		return ultimoStato;
	}

	/** Controlla l'APK scaricato. Ritorna "" se va bene, altrimenti il motivo. */
	@UsedByGodot
	public String verificaApk(String percorso) {
		Activity attivita = getActivity();
		if (attivita == null) {
			return "attivita_assente";
		}
		try {
			PackageManager pm = attivita.getPackageManager();
			int flag = Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
			PackageInfo nuovo = pm.getPackageArchiveInfo(percorso, flag);
			if (nuovo == null) {
				return "apk_illeggibile";
			}
			if (!attivita.getPackageName().equals(nuovo.packageName)) {
				return "pacchetto_diverso";
			}
			PackageInfo attuale = pm.getPackageInfo(attivita.getPackageName(), flag);
			if (versione(nuovo) < versione(attuale)) {
				return "versione_vecchia";
			}
			Set<String> firmeNuove = firme(nuovo);
			Set<String> firmeAttuali = firme(attuale);
			if (firmeNuove.isEmpty() || !firmeNuove.equals(firmeAttuali)) {
				return "firma_diversa";
			}
			return "";
		} catch (Exception e) {
			return "errore: " + e;
		}
	}

	private static long versione(PackageInfo info) {
		if (Build.VERSION.SDK_INT >= 28) {
			return info.getLongVersionCode();
		}
		return info.versionCode;
	}

	private static Set<String> firme(PackageInfo info) throws Exception {
		Set<String> risultato = new TreeSet<>();
		Signature[] elenco = null;
		if (Build.VERSION.SDK_INT >= 28) {
			SigningInfo firma = info.signingInfo;
			if (firma != null) {
				elenco = firma.hasMultipleSigners() ? firma.getApkContentsSigners() : firma.getSigningCertificateHistory();
			}
		} else {
			elenco = info.signatures;
		}
		if (elenco == null) {
			return risultato;
		}
		for (Signature s : elenco) {
			byte[] impronta = MessageDigest.getInstance("SHA-256").digest(s.toByteArray());
			StringBuilder testo = new StringBuilder();
			for (byte b : impronta) {
				testo.append(String.format("%02x", b));
			}
			risultato.add(testo.toString());
		}
		return risultato;
	}

	/** Installa l'APK con una sessione: se Android lo permette, senza nessuna conferma. */
	@UsedByGodot
	public void installaApk(final String percorso) {
		final Activity attivita = getActivity();
		if (attivita == null) {
			emitSignal("stato_installazione", Integer.valueOf(PackageInstaller.STATUS_FAILURE), "attivita_assente");
			return;
		}
		new Thread(new Runnable() {
			@Override
			public void run() {
				installa(attivita, percorso);
			}
		}, "nn-aggiornamento").start();
	}

	private void installa(Activity attivita, String percorso) {
		PackageInstaller.Session sessione = null;
		try {
			File file = new File(percorso);
			PackageInstaller installatore = attivita.getPackageManager().getPackageInstaller();
			PackageInstaller.SessionParams parametri = new PackageInstaller.SessionParams(
					PackageInstaller.SessionParams.MODE_FULL_INSTALL);
			parametri.setAppPackageName(attivita.getPackageName());
			parametri.setSize(file.length());
			if (Build.VERSION.SDK_INT >= 31) {
				parametri.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED);
			}
			if (Build.VERSION.SDK_INT >= 33) {
				parametri.setPackageSource(PackageInstaller.PACKAGE_SOURCE_DOWNLOADED_FILE);
			}
			int id = installatore.createSession(parametri);
			sessione = installatore.openSession(id);
			InputStream ingresso = new FileInputStream(file);
			OutputStream uscita = sessione.openWrite("base.apk", 0, file.length());
			byte[] blocco = new byte[65536];
			int letti;
			while ((letti = ingresso.read(blocco)) != -1) {
				uscita.write(blocco, 0, letti);
			}
			sessione.fsync(uscita);
			uscita.close();
			ingresso.close();
			synchronized (this) {
				if (!ricevitoreAttivo) {
					IntentFilter filtro = new IntentFilter(AZIONE_STATO);
					if (Build.VERSION.SDK_INT >= 33) {
						attivita.registerReceiver(ricevitore, filtro, Context.RECEIVER_NOT_EXPORTED);
					} else {
						attivita.registerReceiver(ricevitore, filtro);
					}
					ricevitoreAttivo = true;
				}
			}
			Intent intent = new Intent(AZIONE_STATO).setPackage(attivita.getPackageName());
			int flag = PendingIntent.FLAG_UPDATE_CURRENT;
			if (Build.VERSION.SDK_INT >= 31) {
				flag |= PendingIntent.FLAG_MUTABLE;
			}
			PendingIntent attesa = PendingIntent.getBroadcast(attivita, id, intent, flag);
			ultimoStato = "inviato";
			// Se l'aggiornamento riesce, Android chiude il gioco: va riaperto a mano.
			sessione.commit(attesa.getIntentSender());
			sessione.close();
		} catch (Exception e) {
			if (sessione != null) {
				try {
					sessione.abandon();
				} catch (Exception ignorata) {
					// sessione già chiusa
				}
			}
			ultimoStato = "errore: " + e;
			emitSignal("stato_installazione", Integer.valueOf(PackageInstaller.STATUS_FAILURE), e.toString());
		}
	}

	// ------------------------------------------------------------ schermo

	/** Modi dello schermo: "id,larghezza,altezza,hz;..." e, dopo "|", il modo attuale e se c'è l'HDR. */
	@UsedByGodot
	public String modiSchermo() {
		Activity attivita = getActivity();
		if (attivita == null) {
			return "";
		}
		Display schermo = Build.VERSION.SDK_INT >= 30 ? attivita.getDisplay() : attivita.getWindowManager().getDefaultDisplay();
		if (schermo == null) {
			return "";
		}
		StringBuilder testo = new StringBuilder();
		for (Display.Mode m : schermo.getSupportedModes()) {
			if (testo.length() > 0) {
				testo.append(';');
			}
			testo.append(m.getModeId()).append(',').append(m.getPhysicalWidth()).append(',')
					.append(m.getPhysicalHeight()).append(',').append(m.getRefreshRate());
		}
		Display.Mode attuale = schermo.getMode();
		boolean hdr = false;
		if (Build.VERSION.SDK_INT >= 26) {
			hdr = schermo.isHdr();
		}
		testo.append('|').append(attuale.getModeId()).append('|').append(hdr ? 1 : 0);
		return testo.toString();
	}

	/** Chiede un modo dello schermo (0 = lascia scegliere ad Android) e una frequenza (0 = nessuna preferenza). */
	@UsedByGodot
	public void chiediModo(final int idModo, final float frequenza) {
		final Activity attivita = getActivity();
		if (attivita == null) {
			return;
		}
		runOnUiThread(new Runnable() {
			@Override
			public void run() {
				Window finestra = attivita.getWindow();
				WindowManager.LayoutParams parametri = finestra.getAttributes();
				parametri.preferredDisplayModeId = idModo;
				parametri.preferredRefreshRate = frequenza;
				finestra.setAttributes(parametri);
			}
		});
	}

	// ------------------------------------------------------------ suono

	/** Dove va il suono del gioco: altoparlante, cuffie, bluetooth, usb, hdmi o altro. */
	@UsedByGodot
	public String uscitaAudio() {
		Activity attivita = getActivity();
		if (attivita == null) {
			return "";
		}
		AudioManager audio = (AudioManager) attivita.getSystemService(Context.AUDIO_SERVICE);
		if (audio == null) {
			return "";
		}
		if (Build.VERSION.SDK_INT >= 33) {
			AudioAttributes attributi = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).build();
			List<AudioDeviceInfo> uscite = audio.getAudioDevicesForAttributes(attributi);
			if (uscite != null && !uscite.isEmpty()) {
				return tipo(uscite.get(0).getType());
			}
		}
		// Prima di Android 13: la più "personale" fra quelle collegate.
		String scelta = "altoparlante";
		for (AudioDeviceInfo d : audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
			String t = tipo(d.getType());
			if (t.equals("bluetooth") || t.equals("cuffie") || t.equals("usb")) {
				return t;
			}
			if (t.equals("hdmi")) {
				scelta = t;
			}
		}
		return scelta;
	}

	private static String tipo(int t) {
		switch (t) {
			case AudioDeviceInfo.TYPE_BUILTIN_SPEAKER:
			case AudioDeviceInfo.TYPE_BUILTIN_EARPIECE:
				return "altoparlante";
			case AudioDeviceInfo.TYPE_WIRED_HEADSET:
			case AudioDeviceInfo.TYPE_WIRED_HEADPHONES:
				return "cuffie";
			case AudioDeviceInfo.TYPE_BLUETOOTH_A2DP:
			case AudioDeviceInfo.TYPE_BLUETOOTH_SCO:
			case AudioDeviceInfo.TYPE_BLE_HEADSET:
			case AudioDeviceInfo.TYPE_BLE_SPEAKER:
			case AudioDeviceInfo.TYPE_BLE_BROADCAST:
				return "bluetooth";
			case AudioDeviceInfo.TYPE_USB_DEVICE:
			case AudioDeviceInfo.TYPE_USB_HEADSET:
			case AudioDeviceInfo.TYPE_USB_ACCESSORY:
				return "usb";
			case AudioDeviceInfo.TYPE_HDMI:
			case AudioDeviceInfo.TYPE_HDMI_ARC:
			case AudioDeviceInfo.TYPE_HDMI_EARC:
				return "hdmi";
			default:
				return "altro";
		}
	}

	/** 0 = silenzioso, 1 = vibrazione, 2 = normale (-1 se non si sa). */
	@UsedByGodot
	public int suoneria() {
		Activity attivita = getActivity();
		if (attivita == null) {
			return -1;
		}
		AudioManager audio = (AudioManager) attivita.getSystemService(Context.AUDIO_SERVICE);
		return audio == null ? -1 : audio.getRingerMode();
	}

	// ------------------------------------------------------------------ dispositivo

	/** Tutto quello che Android lascia sapere sul dispositivo senza permessi, in JSON (letto una volta). */
	@UsedByGodot
	public String infoDispositivo() {
		JSONObject d = new JSONObject();
		Activity attivita = getActivity();
		try {
			d.put("produttore", Build.MANUFACTURER);
			d.put("marca", Build.BRAND);
			d.put("modello", Build.MODEL);
			d.put("nome_dispositivo", Build.DEVICE);
			d.put("build", Build.DISPLAY);
			d.put("android", Build.VERSION.RELEASE);
			d.put("sdk", Build.VERSION.SDK_INT);
			d.put("patch_sicurezza", Build.VERSION.SECURITY_PATCH);
			d.put("hardware", Build.HARDWARE);
			d.put("scheda", Build.BOARD);
			JSONArray abi = new JSONArray();
			for (String a : Build.SUPPORTED_ABIS) {
				abi.put(a);
			}
			d.put("abi", abi);
			if (Build.VERSION.SDK_INT >= 31) {
				d.put("soc_produttore", Build.SOC_MANUFACTURER);
				d.put("soc_modello", Build.SOC_MODEL);
				d.put("classe_prestazioni", Build.VERSION.MEDIA_PERFORMANCE_CLASS);
			}
			d.put("core", Runtime.getRuntime().availableProcessors());
			d.put("frequenza_max_mhz", frequenzaMassimaMhz());
			if (attivita != null) {
				ActivityManager am = (ActivityManager) attivita.getSystemService(Context.ACTIVITY_SERVICE);
				if (am != null) {
					ActivityManager.MemoryInfo m = new ActivityManager.MemoryInfo();
					am.getMemoryInfo(m);
					d.put("ram_mb", m.totalMem / 1048576L);
					d.put("ram_libera_mb", m.availMem / 1048576L);
					d.put("poca_memoria", am.isLowRamDevice());
					d.put("memoria_app_mb", am.getLargeMemoryClass());
				}
				StatFs spazio = new StatFs(attivita.getFilesDir().getAbsolutePath());
				d.put("spazio_libero_mb", spazio.getAvailableBytes() / 1048576L);
				d.put("spazio_totale_mb", spazio.getTotalBytes() / 1048576L);
				PackageManager pm = attivita.getPackageManager();
				d.put("vulkan", pm.hasSystemFeature("android.hardware.vulkan.level"));
				SensorManager sensori = (SensorManager) attivita.getSystemService(Context.SENSOR_SERVICE);
				if (sensori != null) {
					d.put("giroscopio", sensori.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null);
					d.put("accelerometro", sensori.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null);
				}
				Vibrator vibrazione = (Vibrator) attivita.getSystemService(Context.VIBRATOR_SERVICE);
				d.put("vibrazione", vibrazione != null && vibrazione.hasVibrator());
				d.put("vibrazione_dosabile", vibrazione != null && vibrazione.hasAmplitudeControl());
				PowerManager energia = (PowerManager) attivita.getSystemService(Context.POWER_SERVICE);
				d.put("prestazioni_sostenute", energia != null && energia.isSustainedPerformanceModeSupported());
			}
		} catch (Exception e) {
			try {
				d.put("errore", e.toString());
			} catch (Exception ignorata) {
				// niente da fare
			}
		}
		return d.toString();
	}

	/** "risparmio|modo": risparmio energetico (0/1) e modalità gioco di Android
	 *  (0 non disponibile, 1 normale, 2 prestazioni, 3 batteria, 4 personalizzata). Si legge spesso. */
	@UsedByGodot
	public String statoEnergia() {
		Activity attivita = getActivity();
		if (attivita == null) {
			return "-1|0";
		}
		int risparmio = -1;
		PowerManager energia = (PowerManager) attivita.getSystemService(Context.POWER_SERVICE);
		if (energia != null) {
			risparmio = energia.isPowerSaveMode() ? 1 : 0;
		}
		int modo = 0;
		if (Build.VERSION.SDK_INT >= 31) {
			GameManager giochi = (GameManager) attivita.getSystemService(Context.GAME_SERVICE);
			if (giochi != null) {
				modo = giochi.getGameMode();
			}
		}
		return risparmio + "|" + modo;
	}

	private static int frequenzaMassimaMhz() {
		// La frequenza più alta tra i core (i file di sistema si leggono senza permessi su quasi tutti i telefoni).
		int massima = -1;
		for (int i = 0; i < 16; i++) {
			File f = new File("/sys/devices/system/cpu/cpu" + i + "/cpufreq/cpuinfo_max_freq");
			if (!f.exists()) {
				continue;
			}
			try (BufferedReader r = new BufferedReader(new FileReader(f))) {
				String riga = r.readLine();
				if (riga != null) {
					massima = Math.max(massima, Integer.parseInt(riga.trim()) / 1000);
				}
			} catch (Exception e) {
				// illeggibile: si va avanti
			}
		}
		return massima;
	}
}
