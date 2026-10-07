// Exact package IDs avoid classifying an app as a bank merely because its name
// happens to contain words such as "money". This is a curated heuristic, not a
// claim to recognise every banking app in the world.
const BANKS: &[&str] = &[
    "com.vietcombank.vcbmobile",
    "com.vcbmobile",
    "com.vnpay.bidv",
    "com.vietinbank.ipay",
    "com.mbmobile",
    "com.vnpay.agribank",
    "com.techcombank.retail",
    "vn.com.techcombank.bb.app",
    "com.vnpay.vpbank",
    "com.vpbank.vpbankonline",
    "com.vnpay.hdbank",
    "com.sacombank.ewallet",
    "src.com.sacombank",
    "com.acb.acbonline",
    "mobile.acb.com.vn",
    "com.tpb.mb.gprsandroid",
    "com.tpb.ebank",
    "com.vib.myvib2",
    "com.vnpay.eximbank",
    "com.shb.mb",
    "vn.com.msb.smartBanking",
    "com.dongabank.ebanking",
    "com.ocb.omni",
    "com.vnpay.namabank",
    "com.chase.sig.android",
    "com.infonow.bofa",
    "com.wf.wellsfargomobile",
    "com.citi.citimobile",
    "com.usbank.mobilebanking",
    "com.konylabs.capitalone",
    "com.revolut.revolut",
    "de.number26.android",
    "com.starlingbank.android",
    "co.uk.getmondo",
    "uk.co.hsbc.hsbcukmobilebanking",
];
const SOCIAL: &[&str] = &[
    "com.facebook.katana",
    "com.facebook.lite",
    "com.facebook.orca",
    "com.instagram.android",
    "com.twitter.android",
    "com.zing.zalo",
    "com.zhiliaoapp.musically",
    "com.ss.android.ugc.trill",
    "com.snapchat.android",
    "com.reddit.frontpage",
    "com.discord",
    "org.telegram.messenger",
    "org.thunderdog.challegram",
    "com.whatsapp",
    "com.whatsapp.w4b",
    "org.thoughtcrime.securesms",
    "jp.naver.line.android",
    "com.viber.voip",
    "com.linkedin.android",
    "com.pinterest",
    "com.bsky.app",
    "com.google.android.youtube",
    "com.google.android.apps.youtube.music",
];

pub fn classify(package: &str, android_category: i32) -> (String, String) {
    if BANKS.contains(&package) {
        ("banking".into(), "package_catalog".into())
    } else if SOCIAL.contains(&package) {
        ("social".into(), "package_catalog".into())
    } else if android_category == 4 {
        ("social".into(), "android_category".into())
    } else {
        ("other".into(), "unknown".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn recognises_known_ids_without_name_guessing() {
        assert_eq!(classify("com.mbmobile", -1).0, "banking");
        assert_eq!(classify("com.zing.zalo", -1).0, "social");
        assert_eq!(classify("com.example.moneygame", -1).0, "other");
        assert_eq!(classify("com.example.newsocial", 4).1, "android_category");
    }
}
