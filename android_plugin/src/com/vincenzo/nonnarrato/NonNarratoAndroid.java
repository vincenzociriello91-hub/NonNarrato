package com.vincenzo.nonnarrato;

// Plugin Android di NonNarrato (Godot, plugin v2).
// Fa le cose che GDScript da solo non può fare bene:
//  - installare l'aggiornamento scaricato da GitHub con una sessione di PackageInstaller,
//    senza conferme quando Android lo permette (aggiornamento di sé stesso, API 31+);
//  - leggere i modi dello schermo e chiederne uno (risoluzione e frequenza);
//  - capire dove va il suono (altoparlante, cuffie, Bluetooth, USB) e se il telefono è silenzioso.
// Compilato dalla compilazione su GitHub (strumenti/compila_plugin.sh) e messo in addons/.

import android.app.Activity;
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
import android.os.Build;
import android.provider.Settings;
import android.view.Display;
import android.view.Window;
import android.view.WindowManager;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
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
}
