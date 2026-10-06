import Foundation

/// Common coffee descriptors, loosely following the SCA flavor wheel. All lowercase.
/// Multi-word terms are matched before single words so "dark chocolate" wins over "chocolate".
enum FlavorVocabulary {
    static let descriptors: [String] = [
        // Fruity
        "berry", "blueberry", "raspberry", "strawberry", "blackberry", "cranberry", "cherry",
        "dried fruit", "raisin", "prune", "fig", "date",
        "citrus", "lemon", "lime", "orange", "grapefruit", "bergamot",
        "stone fruit", "peach", "apricot", "plum", "nectarine",
        "apple", "pear", "grape", "melon", "pineapple", "mango", "papaya", "passion fruit",
        "tropical", "banana", "coconut", "pomegranate", "fruity", "jammy",
        // Floral / herbal
        "floral", "jasmine", "rose", "lavender", "chamomile", "hibiscus", "honeysuckle",
        "black tea", "green tea", "tea-like", "herbal", "mint", "eucalyptus",
        // Sweet
        "sweet", "honey", "caramel", "toffee", "butterscotch", "brown sugar", "molasses",
        "maple", "vanilla", "marshmallow", "sugar cane", "syrupy",
        // Nutty / cocoa
        "nutty", "almond", "hazelnut", "peanut", "walnut", "pecan",
        "cocoa", "chocolate", "dark chocolate", "milk chocolate", "cacao nibs",
        // Spices
        "spicy", "cinnamon", "clove", "nutmeg", "cardamom", "anise", "pepper", "ginger",
        // Roasted / other
        "roasty", "smoky", "toasty", "tobacco", "cedar", "woody", "earthy", "malty",
        "bready", "cereal", "grainy", "burnt", "ashy", "rubbery",
        // Sour / fermented
        "winey", "wine-like", "boozy", "fermented", "whiskey", "rum",
        // Acidity and mouthfeel
        "bright", "acidic", "tart", "crisp", "juicy", "mellow", "balanced", "complex",
        "clean", "smooth", "creamy", "silky", "velvety", "buttery", "rich", "heavy",
        "full body", "medium body", "light body", "thin", "watery", "dry", "astringent",
        "bitter", "lingering", "long finish", "short finish",
    ]

    /// Terms sorted so longer (multi-word) entries are tried first.
    static let matchOrder: [String] = descriptors.sorted { a, b in
        if a.count != b.count { return a.count > b.count }
        return a < b
    }
}
