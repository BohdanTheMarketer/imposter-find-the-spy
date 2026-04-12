import Foundation

enum CategoryLoader {
    static func loadCategories() -> [Category] {
        let fileNames = [
            "party_time",
            "food",
            "celebrities",
            "hobbies",
            "family",
            "school",
            "spicy",
            "sports",
            "travel",
            "work_life",
            "movies",
            "shopping",
            "tech",
            "superpowers",
            "music",
            "places"
        ]

        var categories: [Category] = []

        for fileName in fileNames {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
                print("[CategoryLoader] Failed to locate \(fileName).json in bundle")
                AnalyticsService.logEvent("category_load_failed", parameters: ["file": fileName])
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                let wordPack = try JSONDecoder().decode(WordPack.self, from: data)
                let category = Category(
                    name: wordPack.category,
                    icon: wordPack.icon,
                    description: wordPack.description,
                    words: wordPack.words,
                    imposterHints: wordPack.imposterHints ?? [],
                    isPremium: wordPack.isPremium
                )
                categories.append(category)
            } catch {
                print("[CategoryLoader] Failed to decode \(fileName): \(error)")
                AnalyticsService.logEvent("category_load_failed", parameters: ["file": fileName])
            }
        }

        // Fallback: if bundle loading fails, use hardcoded categories
        if categories.isEmpty {
            categories = defaultCategories()
        }

        return categories
    }

    private static func defaultCategories() -> [Category] {
        return [
            Category(name: "Party Time", icon: "party.popper", description: "Easygoing fun with laughs and a bit of chaos — perfect for any group vibe!", words: ["DJ", "Karaoke", "Beer Pong", "Dance Floor", "Cocktail", "Disco Ball", "Confetti", "Shot Glass", "Limbo", "Bouncer", "Playlist", "Strobe Light", "Red Cup", "Toast", "Champagne", "Photo Booth", "Balloon", "Costume", "Hangover", "Designated Driver", "Ice Breaker", "Dare", "Spin the Bottle", "Body Shot", "Conga Line", "Foam Party", "VIP Section", "Cover Charge", "Last Call", "Jukebox", "Keg Stand", "Flip Cup", "Glow Stick", "Crowd Surf", "Encore", "Pregame", "Afterparty", "House Party", "Pool Party", "Roof Party", "Toga Party", "Theme Party", "Open Bar", "Punch Bowl", "Bartender", "Smoke Machine", "Laser Show", "Mosh Pit", "Stage Dive", "Rave"], isPremium: false),
            Category(name: "Food", icon: "fork.knife", description: "Tasty topics, but say the wrong thing and you're toast!", words: ["Sushi", "Barbecue", "Vegan", "Pizza", "Taco", "Croissant", "Pancake", "Waffle", "Burrito", "Ramen", "Dim Sum", "Fondue", "Soufflé", "Paella", "Ceviche", "Cheeseburger", "Hot Dog", "French Fries", "Onion Rings", "Milkshake", "Ice Cream Sundae", "Brownie", "Cheesecake", "Tiramisu", "Crème Brûlée", "Lobster", "Caviar", "Truffle", "Oyster", "Filet Mignon", "Avocado Toast", "Acai Bowl", "Smoothie", "Kale Salad", "Kombucha", "Food Truck", "Buffet", "Doggy Bag", "Tip Jar", "Drive-Through", "Chopsticks", "Fortune Cookie", "Sriracha", "Wasabi", "Maple Syrup", "Peanut Butter", "Nutella", "Sourdough", "Bacon", "Fried Chicken"], isPremium: false),
            Category(name: "Family", icon: "house.fill", description: "Family knows you best — but can they still catch you faking it?", words: ["Grandma", "Dinner Table", "Road Trip", "Family Photo", "Bedtime Story", "Sibling Rivalry", "Chores", "Allowance", "Curfew", "Grounding", "Baby Shower", "Thanksgiving", "Christmas Tree", "Birthday Cake", "Family Reunion", "Minivan", "Diaper", "Lullaby", "Babysitter", "High Chair", "Bunk Bed", "Treehouse", "Homework", "Report Card", "School Bus", "Family Pet", "Goldfish", "Backyard BBQ", "Garage Sale", "Attic", "Basement", "Family Album", "Vacation", "Camping", "Board Game Night", "Pillow Fight", "Hide and Seek", "Tooth Fairy", "Santa Claus", "Easter Egg", "Prom Night", "Graduation", "Wedding", "Anniversary", "Retirement", "Inheritance", "Family Recipe", "Sunday Brunch", "Carpool", "Lemonade Stand"], isPremium: false),
            Category(name: "School & College", icon: "book.fill", description: "Relive the chaos of school days — from pop quizzes to prom drama!", words: ["Homework", "Cafeteria", "Principal", "Pop Quiz", "Detention", "Locker", "Chalkboard", "School Bus", "Recess", "Hall Pass", "Valedictorian", "Yearbook", "Prom King", "Cheerleader", "Mascot", "Field Trip", "Science Fair", "Book Report", "Spelling Bee", "Gym Class", "Substitute Teacher", "Honor Roll", "Freshman", "Sorority", "Fraternity", "Dormitory", "Finals Week", "All-Nighter", "Dean", "Scholarship", "Class Clown", "Teacher's Pet", "Truancy", "Graduation Cap", "Student Loan", "Study Group", "Library", "Tutor", "Blackboard", "Eraser", "Backpack", "Lunch Box", "School Nurse", "Fire Drill", "Assembly", "Pledge", "Textbook", "Lab Partner", "Exchange Student", "Homecoming"], isPremium: false),
            Category(name: "Places", icon: "map.fill", description: "From airports to zoos — describe the place without giving it away!", words: ["Airport", "Museum", "Hospital", "Beach", "Casino", "Library", "Zoo", "Amusement Park", "Gym", "Restaurant", "Cemetery", "Prison", "Church", "Stadium", "Mall", "Subway Station", "Lighthouse", "Volcano", "Waterfall", "Desert", "Igloo", "Treehouse", "Skyscraper", "Barn", "Haunted House", "Cruise Ship", "Space Station", "Oil Rig", "Vineyard", "Spa", "Laundromat", "Junkyard", "Rooftop", "Underground Bunker", "Penthouse", "Cabin", "Campsite", "Drive-In Theater", "Bowling Alley", "Arcade", "Car Wash", "Gas Station", "Parking Lot", "Elevator", "Balcony", "Backstage", "Courtroom", "Dentist Office", "Barbershop", "Tattoo Parlor"], isPremium: true),
            Category(name: "Sports", icon: "sportscourt.fill", description: "Goals, fouls, and touchdowns — can you fake your way through sports talk?", words: ["Goalkeeper", "Referee", "Dumbbell", "Slam Dunk", "Penalty Kick", "Marathon", "Boxing Ring", "Surfboard", "Skateboard", "Trampoline", "Wrestling", "Archery", "Fencing", "Javelin", "Hurdles", "Relay Race", "High Jump", "Pole Vault", "Shot Put", "Decathlon", "Touchdown", "Home Run", "Hat Trick", "Hole in One", "Knockout", "Free Throw", "Corner Kick", "Yellow Card", "Offside", "Overtime", "Trophy", "Medal", "Podium", "Victory Lap", "Halftime", "Cheerleader", "Mascot", "Locker Room", "Bench Press", "Treadmill", "Yoga Mat", "Protein Shake", "Warm Up", "Cool Down", "Personal Trainer", "MVP", "Draft Pick", "Trade Deadline", "Playoff", "Championship Ring"], isPremium: true),
            Category(name: "Spicy", icon: "flame.fill", description: "Things get heated — risky words for bold players only!", words: ["Handcuffs", "Blind Date", "Skinny Dipping", "Love Letter", "Flirting", "Jealousy", "Heartbreak", "Crush", "Secret Admirer", "Lipstick Mark", "Slow Dance", "Candlelit Dinner", "Rose Petals", "Chocolate Strawberry", "Massage", "Hot Tub", "Dare", "Truth or Dare", "Seven Minutes", "Spin the Bottle", "Wink", "Pickup Line", "Love Triangle", "Rebound", "Ghosting", "Situationship", "Friends with Benefits", "Wingman", "Walk of Shame", "Morning After", "Strip Poker", "Body Language", "Chemistry", "Butterflies", "Soulmate", "Ex", "DM Slide", "Netflix and Chill", "Date Night", "Long Distance", "Love Potion", "Aphrodisiac", "Seduction", "Temptation", "Forbidden Fruit", "Guilty Pleasure", "Fantasy", "Role Play", "Rendezvous", "Affair"], isPremium: true),
            Category(name: "Movies & TV", icon: "film.fill", description: "Lights, camera, action! Describe movie things without spoiling it!", words: ["Popcorn", "Director", "Sequel", "Plot Twist", "Cliffhanger", "Red Carpet", "Oscar", "Stunt Double", "Blooper", "End Credits", "Trailer", "Box Office", "Premiere", "Cameo", "Casting Couch", "Green Screen", "Special Effects", "Sound Track", "Opening Scene", "Flashback", "Narrator", "Villain", "Sidekick", "Love Interest", "Anti-Hero", "Jump Scare", "Car Chase", "Explosion", "Montage", "Time Travel", "Zombie", "Alien Invasion", "Heist", "Courtroom Drama", "Musical Number", "Documentary", "Animation", "Noir", "Western", "Superhero", "Binge Watch", "Season Finale", "Spoiler Alert", "Fan Theory", "Reboot", "Spin-Off", "Crossover", "Post-Credits", "Director's Cut", "Film Festival"], isPremium: true),
            Category(name: "Animals", icon: "pawprint.fill", description: "Furry, scaly, or feathered — describe the creature without naming it!", words: ["Penguin", "Chameleon", "Hamster", "Flamingo", "Porcupine", "Platypus", "Armadillo", "Jellyfish", "Octopus", "Seahorse", "Peacock", "Sloth", "Koala", "Kangaroo", "Alpaca", "Hedgehog", "Raccoon", "Skunk", "Bat", "Owl", "Parrot", "Toucan", "Pelican", "Vulture", "Eagle", "Shark", "Dolphin", "Whale", "Stingray", "Piranha", "Gorilla", "Chimpanzee", "Orangutan", "Lemur", "Meerkat", "Hyena", "Cheetah", "Panther", "Rhino", "Hippo", "Crocodile", "Iguana", "Gecko", "Cobra", "Python", "Tarantula", "Scorpion", "Firefly", "Praying Mantis", "Axolotl"], isPremium: false),
            Category(name: "Work", icon: "briefcase.fill", description: "Office drama, deadlines, and coffee breaks — the daily grind!", words: ["Deadline", "Coffee Break", "Boss", "Intern", "Promotion", "Pink Slip", "Water Cooler", "Cubicle", "Open Office", "Corner Office", "Business Card", "Power Point", "Team Building", "Happy Hour", "Lunch Break", "Conference Call", "Zoom Meeting", "Mute Button", "Screen Share", "Email Chain", "Reply All", "Out of Office", "Sick Day", "Vacation Days", "Remote Work", "Dress Code", "Casual Friday", "Name Tag", "Security Badge", "Elevator Pitch", "Networking", "LinkedIn", "Resume", "Cover Letter", "Job Interview", "Salary", "Bonus", "Stock Options", "Pension", "Retirement Party", "Office Gossip", "Brown Nosing", "Micromanager", "Whistleblower", "Burnout", "Side Hustle", "Freelancer", "Startup", "Coworking Space", "Annual Review"], isPremium: true)
        ]
    }
}
