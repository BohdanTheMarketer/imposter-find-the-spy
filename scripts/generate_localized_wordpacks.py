#!/usr/bin/env python3
"""Generate culturally adapted word packs for pt-BR, fr, es-MX, tr from en templates."""

import copy
import json
import time
from pathlib import Path

try:
    from deep_translator import GoogleTranslator
except ImportError:
    GoogleTranslator = None  # type: ignore

ROOT = Path(__file__).resolve().parents[1]
EN_DIR = ROOT / "ImposterGame/Resources/WordPacks/en"

# Per-locale: category/description translations + word/hint index overrides (0-based)
LOCALE_PACKS: dict[str, dict[str, dict]] = {
    "pt-BR": {
        "party_time": {
            "category": "Hora da Festa",
            "description": "Caos divertido e risadas altas — perfeito para quebrar o gelo em qualquer grupo!",
            "overrides": {
                0: ("Carnaval", "desfile de rua"),
                6: ("Forró", "dança de salão"),
                9: ("Caipirinha", "bebida nacional"),
                14: ("Feijoada", "prato de feijão"),
                17: ("Brigadeiro", "doce de chocolate"),
                22: ("Telenovela", "novela da TV"),
                28: ("Samba", "ritmo de carnaval"),
                35: ("Pão de queijo", "lanche mineiro"),
            },
        },
        "food": {
            "category": "Comida",
            "description": "Temas saborosos — erre e vira piada na mesa!",
            "overrides": {
                0: ("Feijoada", "feijão preto"),
                3: ("Açaí", "tigela roxa"),
                8: ("Brigadeiro", "bolinha de chocolate"),
                12: ("Pão de queijo", "lanche quente"),
                18: ("Churrasco", "carne na brasa"),
                25: ("Moqueca", "ensopado de peixe"),
                30: ("Coxinha", "salgadinho"),
                40: ("Pastel", "frito na feira"),
            },
        },
        "celebrities": {
            "category": "Celebridades",
            "description": "Famosos, ícones e estrelas — quem não conhece, desconfie!",
            "overrides": {
                0: ("Neymar", "jogador de futebol"),
                5: ("Anitta", "cantora pop"),
                10: ("Pelé", "rei do futebol"),
                15: ("Xuxa", "apresentadora"),
                20: ("Gisele Bündchen", "supermodelo"),
                25: ("Caetano Veloso", "MPB"),
                30: ("Ivete Sangalo", "axé"),
            },
        },
        "sports": {
            "category": "Esportes",
            "description": "Bola, quadra e torcida — quem não sabe, levanta suspeita!",
            "overrides": {
                0: ("Brasileirão", "liga nacional"),
                5: ("Maracanã", "estádio gigante"),
                10: ("Futebol", "esporte rei"),
                15: ("Vôlei", "rede alta"),
                20: ("Surf", "onda no mar"),
                25: ("Capoeira", "luta dançada"),
                30: ("Formula 1", "Interlagos"),
            },
        },
        "movies": {
            "category": "Filmes",
            "description": "Cinema, streaming e clássicos — spoiler vira suspeita!",
            "overrides": {
                0: ("Cidade de Deus", "filme brasileiro"),
                8: ("Tropa de Elite", "policial RJ"),
                15: ("Central do Brasil", "drama rodoviário"),
                22: ("O Auto da Compadecida", "comédia nordestina"),
            },
        },
        "music": {
            "category": "Música",
            "description": "Ritmo, letra e refrão — quem não canta junto, desconfie!",
            "overrides": {
                0: ("Bossa Nova", "samba suave"),
                5: ("Samba", "carnaval"),
                10: ("Forró", "Sanfona"),
                15: ("Funk carioca", "batida pesada"),
                20: ("MPB", "música popular"),
                25: ("Axé", "Bahia"),
                30: ("Sertanejo", "moda de viola"),
            },
        },
        "travel": {
            "category": "Viagem",
            "description": "Destinos, malas e aventuras — quem nunca foi, inventa!",
            "overrides": {
                0: ("Copacabana", "praia famosa"),
                5: ("Amazônia", "floresta"),
                10: ("Foz do Iguaçu", "cachoeiras"),
                15: ("Salvador", "Pelourinho"),
                20: ("Gramado", "serra gaúcha"),
                25: ("Fernando de Noronha", "ilha"),
            },
        },
        "work_life": {
            "category": "Vida Profissional",
            "description": "Escritório, reuniões e café — quem nunca trabalhou, inventa!",
            "overrides": {
                0: ("Home office", "trabalho remoto"),
                10: ("LinkedIn", "rede profissional"),
                20: ("13º salário", "bônus anual"),
            },
        },
        "school": {
            "category": "Escola",
            "description": "Sala de aula, provas e recreio — quem não estudou, inventa!",
            "overrides": {
                0: ("Vestibular", "entrada na faculdade"),
                5: ("ENEM", "prova nacional"),
                10: ("Uniforme", "camisa da escola"),
            },
        },
        "family": {
            "category": "Família",
            "description": "Parentes, festas e tradições — quem não tem, inventa!",
            "overrides": {
                0: ("Churrasco de domingo", "família reunida"),
                10: ("Avó", "cozinheira"),
                20: ("Primo", "mesma família"),
            },
        },
        "hobbies": {
            "category": "Hobbies",
            "description": "Passatempos e diversão — quem não tem hobby, inventa!",
            "overrides": {
                0: ("Futebol amador", "pelada"),
                10: ("Praia", "areia e sol"),
                20: ("Jardinagem", "plantas"),
            },
        },
        "shopping": {
            "category": "Compras",
            "description": "Lojas, preços e promoções — quem não compra, inventa!",
            "overrides": {
                0: ("Feira livre", "rua de barracas"),
                10: ("Shopping", "centro comercial"),
                20: ("Pix", "pagamento instantâneo"),
            },
        },
        "tech": {
            "category": "Tecnologia",
            "description": "Apps, gadgets e internet — quem não entende, inventa!",
            "overrides": {
                0: ("WhatsApp", "mensagens"),
                10: ("Instagram", "fotos"),
                20: ("Pix", "transferência"),
            },
        },
        "superpowers": {
            "category": "Superpoderes",
            "description": "Poderes impossíveis — quem não sonhou, inventa!",
            "overrides": {},
        },
        "places": {
            "category": "Lugares",
            "description": "Cidades, locais e cenários — quem nunca foi, inventa!",
            "overrides": {
                0: ("São Paulo", "megacidade"),
                5: ("Rio de Janeiro", "Cristo Redentor"),
                10: ("Brasília", "capital"),
            },
        },
        "world_cup": {
            "category": "Copa do Mundo",
            "description": "Gols, drama e paixão nacional. Saiba seu futebol ou fique impedido!",
            "overrides": {
                28: ("Maracanã", "estádio carioca"),
                33: ("Neymar", "camisa 10"),
                34: ("Pelé", "rei do futebol"),
                35: ("Brasil", "amarelinha"),
                36: ("Argentina", "albiceleste"),
            },
        },
        "spicy": {
            "category": "Picante",
            "description": "Temas ousados com humor — mantenha na brincadeira!",
            "overrides": {
                0: ("Flerte", "olhar cúmplice"),
                5: ("Crush secreto", "paixão escondida"),
                10: ("Jantar à luz de velas", "romântico"),
                15: ("Primeiro beijo", "lábios"),
                20: ("Mensagem ousada", "texto picante"),
            },
        },
    },
    "fr": {
        "party_time": {
            "category": "Ambiance Festive",
            "description": "Chaos joyeux et fous rires — parfait pour briser la glace !",
            "overrides": {
                0: ("Apéritif", "avant le dîner"),
                6: ("Champagne", "bulles"),
                10: ("Pétanque", "boules"),
                15: ("Crêpe", "galette fine"),
                20: ("Soirée", "fête"),
            },
        },
        "food": {
            "category": "Cuisine",
            "description": "Saveurs et gourmandise — une fausse piste et c'est grillé !",
            "overrides": {
                0: ("Croissant", "viennoiserie"),
                5: ("Baguette", "pain long"),
                10: ("Fromage", "affiné"),
                15: ("Boulangerie", "four"),
                20: ("Ratatouille", "plat du sud"),
                25: ("Crêpe", "dessert"),
                30: ("Escargot", "coquille"),
            },
        },
        "celebrities": {
            "category": "Célébrités",
            "description": "Stars et icônes — qui ne connaît pas, suspect !",
            "overrides": {
                0: ("Zinedine Zidane", "footballeur"),
                5: ("Omar Sy", "acteur"),
                10: ("Édith Piaf", "chanteuse"),
                15: ("César", "prix du cinéma"),
                20: ("Victoires de la Musique", "gala musical"),
            },
        },
        "sports": {
            "category": "Sport",
            "description": "Ballon, terrain et supporters — le faux joueur trahit !",
            "overrides": {
                0: ("Tour de France", "vélo"),
                5: ("Roland-Garros", "tennis"),
                10: ("Football", "Ligue 1"),
                15: ("Rugby", "ovalie"),
                20: ("Pétanque", "boules"),
            },
        },
        "movies": {
            "category": "Cinéma",
            "description": "Films et séries — spoiler interdit !",
            "overrides": {
                0: ("Amélie Poulain", "Paris"),
                8: ("Intouchables", "duo"),
                15: ("César", "cérémonie"),
            },
        },
        "music": {
            "category": "Musique",
            "description": "Mélodies et refrains — qui ne chante pas, suspect !",
            "overrides": {
                0: ("Victoires de la Musique", "gala"),
                5: ("Chanson française", "variété"),
                10: ("Édith Piaf", "La Vie en rose"),
                15: ("Daft Punk", "électro"),
            },
        },
        "travel": {
            "category": "Voyage",
            "description": "Destinations et valises — jamais parti ? Invente !",
            "overrides": {
                0: ("Tour Eiffel", "Paris"),
                5: ("Provence", "lavande"),
                10: ("Côte d'Azur", "plage"),
                15: ("Mont-Saint-Michel", "abbaye"),
            },
        },
        "work_life": {
            "category": "Travail",
            "description": "Bureau, réunions et café — le novice se trahit !",
            "overrides": {},
        },
        "school": {
            "category": "École",
            "description": "Cours, copies et récré — le cancre se dévoile !",
            "overrides": {},
        },
        "family": {
            "category": "Famille",
            "description": "Parents, fêtes et traditions — le faux cousin trahit !",
            "overrides": {},
        },
        "hobbies": {
            "category": "Loisirs",
            "description": "Passions et détente — pas de hobby ? Suspect !",
            "overrides": {},
        },
        "shopping": {
            "category": "Shopping",
            "description": "Boutiques et soldes — le faux acheteur trahit !",
            "overrides": {},
        },
        "tech": {
            "category": "Tech",
            "description": "Apps et gadgets — le novice trahit !",
            "overrides": {},
        },
        "superpowers": {
            "category": "Super-pouvoirs",
            "description": "Pouvoirs impossibles — rêve ou mensonge !",
            "overrides": {},
        },
        "places": {
            "category": "Lieux",
            "description": "Villes et paysages — jamais vu ? Invente !",
            "overrides": {
                0: ("Paris", "capitale"),
                5: ("Lyon", "gastronomie"),
                10: ("Marseille", "port"),
            },
        },
        "world_cup": {
            "category": "Coupe du Monde",
            "description": "Buts, drame et fierté nationale. Connais ton foot ou hors-jeu !",
            "overrides": {
                33: ("Mbappé", "attaquant rapide"),
                34: ("Zinedine Zidane", "légende française"),
                39: ("France", "bleu blanc rouge"),
            },
        },
        "spicy": {
            "category": "Coquin",
            "description": "Thèmes osés avec humour — restez fair-play !",
            "overrides": {},
        },
    },
    "es-MX": {
        "party_time": {
            "category": "Fiesta",
            "description": "Caos divertido y risas — ¡perfecto para romper el hielo!",
            "overrides": {
                0: ("Piñata", "dulces"),
                6: ("Mariachi", "trompetas"),
                10: ("Quinceañera", "fiesta de 15"),
                15: ("Cumbia", "baile"),
                20: ("Lucha libre", "máscara"),
            },
        },
        "food": {
            "category": "Comida",
            "description": "Sabores mexicanos — ¡un error y quedas expuesto!",
            "overrides": {
                0: ("Tacos", "tortilla"),
                5: ("Tamales", "hoja de maíz"),
                10: ("Guacamole", "aguacate"),
                15: ("Elote", "maíz"),
                20: ("Pozole", "caldo rojo"),
                25: ("Churros", "azúcar"),
                30: ("Agua de horchata", "arroz"),
            },
        },
        "celebrities": {
            "category": "Celebridades",
            "description": "Famosos y estrellas — ¡quien no sabe, sospecha!",
            "overrides": {
                0: ("Bad Bunny", "reggaetón"),
                5: ("Salma Hayek", "actriz"),
                10: ("Guillermo del Toro", "cine"),
                15: ("Thalía", "telenovela"),
            },
        },
        "sports": {
            "category": "Deportes",
            "description": "Balón, cancha y afición — ¡el falso delata!",
            "overrides": {
                0: ("Liga MX", "fútbol"),
                5: ("Lucha libre", "ring"),
                10: ("Béisbol", "jonrón"),
                15: ("Box", "ring"),
            },
        },
        "movies": {
            "category": "Películas",
            "description": "Cine y streaming — ¡spoiler prohibido!",
            "overrides": {
                0: ("Roma", "Ciudad de México"),
                8: ("Coco", "Día de Muertos"),
            },
        },
        "music": {
            "category": "Música",
            "description": "Ritmo y letra — ¡quien no canta, sospecha!",
            "overrides": {
                0: ("Mariachi", "sombrero"),
                5: ("Cumbia", "acordeón"),
                10: ("Reggaetón", "perreo"),
                15: ("Banda", "trombones"),
            },
        },
        "travel": {
            "category": "Viajes",
            "description": "Destinos y maletas — ¿nunca viajaste? ¡Inventa!",
            "overrides": {
                0: ("Cancún", "playa"),
                5: ("Oaxaca", "mole"),
                10: ("CDMX", "capital"),
                15: ("Chichen Itzá", "pirámide"),
            },
        },
        "work_life": {"category": "Trabajo", "description": "Oficina y juntas — ¡el novato delata!", "overrides": {}},
        "school": {"category": "Escuela", "description": "Clases y recreo — ¡el distraído delata!", "overrides": {}},
        "family": {"category": "Familia", "description": "Parientes y tradiciones — ¡el falso primo delata!", "overrides": {}},
        "hobbies": {"category": "Pasatiempos", "description": "Diversión y hobbies — ¡sin hobby? ¡Sospecha!", "overrides": {}},
        "shopping": {"category": "Compras", "description": "Tianguis y ofertas — ¡el falso comprador delata!", "overrides": {}},
        "tech": {"category": "Tecnología", "description": "Apps y gadgets — ¡el novato delata!", "overrides": {}},
        "superpowers": {"category": "Superpoderes", "description": "Poderes imposibles — ¿sueño o mentira?", "overrides": {}},
        "places": {
            "category": "Lugares",
            "description": "Ciudades y paisajes — ¿nunca fuiste? ¡Inventa!",
            "overrides": {0: ("Ciudad de México", "capital"), 5: ("Guadalajara", "tequila")},
        },
        "world_cup": {
            "category": "Copa Mundial",
            "description": "Goles, drama y orgullo nacional. ¡Conoce tu fútbol o queda fuera de juego!",
            "overrides": {
                28: ("Estadio Azteca", "Ciudad de México"),
                29: ("Azteca", "templo del fútbol"),
                33: ("Messi", "campeón del mundo"),
                35: ("México", "tricolor"),
                36: ("Argentina", "albiceleste"),
            },
        },
        "spicy": {"category": "Picante", "description": "Temas atrevidos con humor — ¡fair play!", "overrides": {}},
    },
    "tr": {
        "party_time": {
            "category": "Parti Zamanı",
            "description": "Eğlenceli kaos ve kahkahalar — buzları kırmak için ideal!",
            "overrides": {
                0: ("Düğün", "halay"),
                6: ("Çay evi", "demlik"),
                10: ("Baklava", "tatlı"),
            },
        },
        "food": {
            "category": "Yemek",
            "description": "Lezzetli konular — yanlış söyleyen ifşa olur!",
            "overrides": {
                0: ("Döner", "et dürüm"),
                5: ("Lahmacun", "ince hamur"),
                10: ("Baklava", "fıstık"),
                15: ("Menemen", "yumurta"),
                20: ("Künefe", "peynirli tatlı"),
                25: ("Turkish coffee", "fincan"),
                30: ("Simit", "halka ekmek"),
            },
        },
        "celebrities": {
            "category": "Ünlüler",
            "description": "Yıldızlar ve ikonlar — bilmeyen şüpheli!",
            "overrides": {
                0: ("Tarkan", "şarkıcı"),
                5: ("Nuri Bilge Ceylan", "yönetmen"),
                10: ("Yeşilçam", "eski sinema"),
                15: ("Hadise", "pop"),
            },
        },
        "sports": {
            "category": "Spor",
            "description": "Top, saha ve taraftar — sahtekar ele verir!",
            "overrides": {
                0: ("Süper Lig", "futbol"),
                5: ("Galatasaray", "tribün"),
                10: ("Beşiktaş", "kartal"),
                15: ("Fenerbahçe", "sarı lacivert"),
                20: ("Yağlı güreş", "Kırkpınar"),
            },
        },
        "movies": {
            "category": "Filmler",
            "description": "Sinema ve diziler — spoiler yasak!",
            "overrides": {0: ("Yeşilçam", "klasik"), 8: ("Nuri Bilge Ceylan", "Cannes")},
        },
        "music": {
            "category": "Müzik",
            "description": "Melodi ve nakarat — bilmeyen şüpheli!",
            "overrides": {
                0: ("Türkü", "halk müziği"),
                5: ("Tarkan", "pop"),
                10: ("Arabesk", "duygusal"),
                15: ("Bağlama", "saz"),
            },
        },
        "travel": {
            "category": "Seyahat",
            "description": "Rotalar ve valiz — gitmediysen uydur!",
            "overrides": {
                0: ("Kapadokya", "balon"),
                5: ("İstanbul", "Boğaz"),
                10: ("Antalya", "sahil"),
                15: ("Pamukkale", "traverten"),
            },
        },
        "work_life": {"category": "İş Hayatı", "description": "Ofis ve toplantılar — acemi ele verir!", "overrides": {}},
        "school": {"category": "Okul", "description": "Ders ve teneffüs — bilmeyen şüpheli!", "overrides": {}},
        "family": {"category": "Aile", "description": "Akrabalar ve gelenekler — sahtekar ele verir!", "overrides": {}},
        "hobbies": {"category": "Hobiler", "description": "Keyif ve uğraşı — hobisi yok mu? Şüpheli!", "overrides": {}},
        "shopping": {"category": "Alışveriş", "description": "Pazar ve indirim — sahtekar ele verir!", "overrides": {}},
        "tech": {"category": "Teknoloji", "description": "Uygulama ve cihaz — acemi ele verir!", "overrides": {}},
        "superpowers": {"category": "Süper Güçler", "description": "İmkansız güçler — rüya mı yalan mı?", "overrides": {}},
        "places": {
            "category": "Mekanlar",
            "description": "Şehirler ve manzaralar — gitmediysen uydur!",
            "overrides": {0: ("İstanbul", "köprü"), 5: ("Ankara", "başkent")},
        },
        "world_cup": {
            "category": "Dünya Kupası",
            "description": "Goller, dram ve millî gurur. Futbolunu bil ya da ofsatta kal!",
            "overrides": {
                33: ("Arda Güler", "genç yetenek"),
                37: ("Türkiye", "ayı yıldız"),
                38: ("Almanya", "siyah beyaz"),
            },
        },
        "spicy": {
            "category": "Cesur",
            "description": "Flört ve romantizm — hafif ve eğlenceli kalsın!",
            "overrides": {
                0: ("Flört", "göz teması"),
                1: ("Eski sevgili", "geçmiş"),
                2: ("Kör randevu", "ilk buluşma"),
                3: ("Tanışma uygulaması", "kaydırma"),
                5: ("Gizli aşk", "kalp"),
                6: ("Romantik dans", "yakın"),
                7: ("Gece sohbeti", "samimi"),
                10: ("Mum ışığında akşam yemeği", "romantik"),
                12: ("Sır", "gizli"),
                15: ("İlk öpücük", "dudak"),
                20: ("Cesur mesaj", "telefon"),
                22: ("Aşk mektubu", "mürekkep"),
                28: ("Çiçek buketi", "romantik"),
                32: ("El ele yürüyüş", "park"),
            },
        },
    },
}

LANG_CODES = {"pt-BR": "pt", "fr": "fr", "es-MX": "es", "tr": "tr"}


def tr_batch(texts: list[str], lang: str) -> list[str]:
    if not GoogleTranslator or not texts:
        return texts
    translator = GoogleTranslator(source="en", target=lang)
    out: list[str] = []
    for i in range(0, len(texts), 40):
        chunk = texts[i : i + 40]
        try:
            out.extend(translator.translate_batch(chunk))
        except Exception:
            out.extend(chunk)
        time.sleep(0.15)
    return out

def localize_pack(en_data: dict, locale: str, pack_name: str) -> dict:
    cfg = LOCALE_PACKS.get(locale, {}).get(pack_name, {})
    out = copy.deepcopy(en_data)
    if "category" in cfg:
        out["category"] = cfg["category"]
    if "description" in cfg:
        out["description"] = cfg["description"]
    overrides = cfg.get("overrides", {})
    words = out.get("words", [])
    hints = out.get("imposterHints", []) or []
    if len(hints) < len(words):
        hints = list(hints) + [""] * (len(words) - len(hints))
    for idx, (w, h) in overrides.items():
        if idx < len(words):
            words[idx] = w
            hints[idx] = h
    # Translate remaining English tokens
    lang = LANG_CODES.get(locale)
    if lang and GoogleTranslator:
        en_words = en_data.get("words", [])
        en_hints = en_data.get("imposterHints") or []
        for i in range(len(words)):
            if i not in overrides and i < len(en_words) and words[i] == en_words[i]:
                pass  # mark for batch below
        word_idx = [
            i
            for i in range(len(words))
            if i not in overrides and i < len(en_words) and words[i] == en_words[i]
        ]
        if word_idx:
            translated = tr_batch([en_words[i] for i in word_idx], lang)
            for idx, val in zip(word_idx, translated):
                words[idx] = val
        hint_idx = [
            i
            for i in range(len(words))
            if i not in overrides
            and i < len(en_hints)
            and (hints[i] if i < len(hints) else "") == en_hints[i]
        ]
        if hint_idx:
            translated_h = tr_batch([en_hints[i] for i in hint_idx], lang)
            for idx, val in zip(hint_idx, translated_h):
                if idx < len(hints):
                    hints[idx] = val
                else:
                    hints.append(val)

    out["words"] = words
    out["imposterHints"] = hints[: len(words)]
    return out


def main() -> None:
    import sys

    locales = list(LOCALE_PACKS.keys())
    if len(sys.argv) > 1:
        locales = [a for a in sys.argv[1:] if a in LOCALE_PACKS]

    for locale in locales:
        packs = LOCALE_PACKS[locale]
        dest = ROOT / "ImposterGame/Resources/WordPacks" / locale
        dest.mkdir(parents=True, exist_ok=True)
        for pack_name in packs:
            en_path = EN_DIR / f"{pack_name}.json"
            if not en_path.exists():
                print(f"skip missing en: {pack_name}")
                continue
            en_data = json.loads(en_path.read_text(encoding="utf-8"))
            localized = localize_pack(en_data, locale, pack_name)
            out_path = dest / f"{pack_name}.json"
            out_path.write_text(
                json.dumps(localized, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            w, h = len(localized["words"]), len(localized["imposterHints"])
            assert w == h, f"{locale}/{pack_name}: {w} != {h}"
            print(f"ok {locale}/{pack_name}.json ({w} words)", flush=True)
    print("done", flush=True)


if __name__ == "__main__":
    main()
