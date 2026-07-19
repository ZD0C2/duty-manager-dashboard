(function (global) {
  "use strict";

  var categories = [
    {
      key: "str-checkin-access",
      label: "Check-in & arrival",
      group: "Arrival",
      route: "guest-support",
      issues: [
        "Cannot find the property", "Cannot enter the building", "Check-in instructions are unclear",
        "Check-in instructions were not received", "Entry code is missing", "Entry code is not working",
        "Early check-in question", "Property is not ready at check-in", "Wrong property or unit instructions",
        "Building entrance is locked", "Concierge or security will not allow entry", "Need step-free arrival help"
      ]
    },
    {
      key: "str-locks-keys-security",
      label: "Keys, lockbox & smart lock",
      group: "Access",
      route: "guest-support",
      issues: [
        "Lockbox will not open", "Lockbox code is incorrect", "Lockbox is empty", "Cannot find the lockbox",
        "Smart lock is offline", "Smart lock battery is low", "Key is missing", "Key is damaged",
        "Key is locked inside", "Door will not unlock", "Door will not lock", "Door will not close",
        "Gate or fob is not working", "Bedroom lock problem", "Window will not lock", "Security concern about access"
      ]
    },
    {
      key: "str-cleaning-maintenance",
      label: "Cleaning & property condition",
      group: "Cleanliness",
      route: "turnover-housekeeping",
      issues: [
        "Property was not cleaned", "Cleaning is incomplete", "Bathroom is not clean", "Kitchen is not clean",
        "Bedroom is not clean", "Dirty floor or carpet", "Bin was not emptied", "Bad smell in the property",
        "Smoke smell", "Mould or damp concern", "Hair or stains found", "Previous guest items remain",
        "Balcony or outdoor area is dirty", "Cleaning supplies were left out", "Urgent re-clean requested",
        "Mid-stay clean question"
      ]
    },
    {
      key: "str-essentials-supplies",
      label: "Missing essentials & supplies",
      group: "Supplies",
      route: "turnover-housekeeping",
      issues: [
        "Toilet roll is missing", "Soap or hand wash is missing", "Shampoo or body wash is missing",
        "Dishwasher tablets are missing", "Washing-up liquid is missing", "Bin bags are missing",
        "Kitchen roll is missing", "Tea or coffee is missing", "Sugar or milk is missing",
        "Cooking basics are missing", "Cleaning products are missing", "Iron or ironing board is missing",
        "Hairdryer is missing", "Hangers are missing", "Baby equipment is missing", "Other promised item is missing"
      ]
    },
    {
      key: "str-bedroom-linen-comfort",
      label: "Bedroom, bedding & towels",
      group: "Comfort",
      route: "turnover-housekeeping",
      issues: [
        "Bedding is missing", "Bedding is stained", "Bedding is damaged", "Extra bedding requested",
        "Towels are missing", "Towels are stained", "Fresh towels requested", "Extra towels requested",
        "Pillow is missing", "Extra pillows requested", "Duvet or blanket requested", "Bed is not made",
        "Bed or mattress is damaged", "Bed is uncomfortable", "Sofa bed is not prepared",
        "Cot or travel bed problem", "Bedroom curtain or blind problem"
      ]
    },
    {
      key: "str-bathroom-water",
      label: "Bathroom, plumbing & hot water",
      group: "Water",
      route: "maintenance",
      issues: [
        "No hot water", "Hot water runs out", "Water is too hot", "Low water pressure", "No water",
        "Shower is not working", "Shower is blocked", "Shower is leaking", "Bath is blocked or leaking",
        "Sink is blocked", "Tap is leaking", "Toilet will not flush", "Toilet is blocked",
        "Toilet is leaking", "Bathroom is flooding", "Drain smell", "Extractor fan is not working",
        "Washing machine leak", "Water leak elsewhere"
      ]
    },
    {
      key: "str-kitchen-appliances",
      label: "Kitchen & appliances",
      group: "Kitchen",
      route: "maintenance",
      issues: [
        "Cooker or hob is not working", "Oven is not working", "Microwave is not working",
        "Fridge is not cooling", "Freezer is not working", "Dishwasher is not working",
        "Washing machine is not working", "Tumble dryer is not working", "Kettle is not working",
        "Coffee machine is not working", "Toaster is not working", "Extractor fan is not working",
        "Appliance instructions needed", "Crockery is missing or damaged", "Cutlery is missing",
        "Cooking utensils are missing", "Kitchen sink is blocked", "Gas supply concern"
      ]
    },
    {
      key: "str-heating-cooling-air",
      label: "Heating, cooling & air quality",
      group: "Comfort",
      route: "maintenance",
      issues: [
        "Property is too cold", "Property is too hot", "Heating will not turn on", "Heating controls are unclear",
        "Radiator is not heating", "Radiator is leaking", "Air conditioning is not cooling",
        "Air conditioning is not heating", "Air conditioning is noisy", "Fan is not working",
        "Window will not open", "Window will not close", "Strong smell from ventilation",
        "Condensation or damp", "Portable heater requested", "Portable fan requested"
      ]
    },
    {
      key: "str-wifi-tv-technology",
      label: "Wi-Fi, TV & smart-home",
      group: "Technology",
      route: "guest-support",
      issues: [
        "Wi-Fi details are missing", "Wi-Fi password is not working", "Wi-Fi will not connect",
        "Wi-Fi is very slow", "Wi-Fi keeps disconnecting", "Internet is unavailable", "TV will not turn on",
        "TV has no picture or sound", "TV remote is missing", "TV remote is not working",
        "Streaming or casting is not working", "Smart speaker is not working", "Smart-home controls are not working",
        "Thermostat app or panel is not working", "Intercom is not working", "Charging point is not working",
        "Technology instructions needed"
      ]
    },
    {
      key: "str-electricity-lighting",
      label: "Electricity, lighting & charging",
      group: "Utilities",
      route: "maintenance",
      issues: [
        "No electricity", "Partial power loss", "Power keeps tripping", "Socket is not working",
        "Socket is loose or damaged", "Light is not working", "Light is flickering", "Light switch is not working",
        "Lights will not turn off", "USB charger is not working", "EV charger problem",
        "Fuse box help needed", "Electrical burning smell", "Sparking or exposed wire"
      ]
    },
    {
      key: "str-noise-neighbours-rules",
      label: "Noise, neighbours & house rules",
      group: "Stay guidance",
      route: "guest-support",
      issues: [
        "Noise from neighbours", "Noise from the street", "Building or construction noise",
        "Party or disturbance nearby", "Neighbour complaint received", "Quiet hours question",
        "Visitor policy question", "Pet policy question", "Smoking policy question", "Building rules question",
        "Shared-area rules question", "Cannot understand a house rule", "Concern about another guest or resident"
      ]
    },
    {
      key: "str-parking-transport",
      label: "Parking & local access",
      group: "Arrival",
      route: "guest-support",
      issues: [
        "Cannot find the parking space", "Parking instructions are unclear", "Parking code or permit is missing",
        "Allocated space is occupied", "Car park gate is not working", "Vehicle height or size question",
        "EV charging question", "Accessible parking question", "Street parking question", "Loading or drop-off question",
        "Public transport directions needed", "Taxi or transfer question"
      ]
    },
    {
      key: "str-outdoor-leisure",
      label: "Balcony, garden, pool & leisure",
      group: "Outdoor",
      route: "maintenance",
      issues: [
        "Balcony door problem", "Balcony or terrace is unsafe", "Garden access problem", "Outdoor lighting problem",
        "Outdoor furniture is damaged", "Barbecue problem", "Pool access problem", "Pool is not clean",
        "Hot tub is not working", "Hot tub is not clean", "Sauna or gym equipment problem",
        "Shared leisure area question", "Outdoor noise concern"
      ]
    },
    {
      key: "str-damage-pests-maintenance",
      label: "Damage, pests & maintenance",
      group: "Property care",
      route: "maintenance",
      issues: [
        "Something was already damaged on arrival", "I accidentally damaged something", "Furniture is broken",
        "Door or window is damaged", "Wall, ceiling or floor is damaged", "Leak or damp damage",
        "Pest or insect concern", "Rodent concern", "Bed bug concern", "Loose fitting or trip hazard",
        "Lift is not working", "Shared building area problem", "Maintenance visit question",
        "Property item needs repair", "Other damage to report"
      ]
    },
    {
      key: "str-checkout-luggage",
      label: "Checkout, luggage & departure",
      group: "Departure",
      route: "guest-support",
      issues: [
        "Checkout instructions are unclear", "Checkout time question", "Late checkout request",
        "Where to leave keys", "Lockbox checkout problem", "Luggage storage question", "Cleaning at checkout question",
        "Rubbish or recycling instructions", "Parking at checkout question", "Forgotten item after checkout",
        "Need proof of stay or receipt", "Need help leaving the building"
      ]
    },
    {
      key: "str-safety-alarms",
      label: "Safety, alarms & urgent concerns",
      group: "Safety",
      route: "safety-escalation",
      emergency: true,
      issues: [
        "Smoke alarm is sounding", "Smoke alarm is beeping", "Carbon monoxide alarm is sounding",
        "Fire or smoke concern", "Gas smell", "Electrical burning smell", "Water is flooding",
        "Door cannot be secured", "Broken glass or sharp hazard", "Unsafe balcony or window",
        "Emergency exit is blocked", "First-aid kit question", "Non-immediate safety concern"
      ]
    },
    {
      key: "str-host-contact-support",
      label: "Host contact, service & complaint",
      group: "Support",
      route: "guest-support",
      issues: [
        "Need to contact the host team", "Previous message was not answered", "Request an update",
        "Booking detail question", "Number of guests question", "Amenity was not as listed",
        "Privacy concern", "Staff or contractor conduct concern", "Accessibility support request",
        "Language or communication help", "General complaint", "Compliment or feedback", "Something else"
      ]
    }
  ];

  var departments = [
    { name: "Guest Support", code: "guest-support", responseTarget: 5, escalation: 15 },
    { name: "Turnover & Housekeeping", code: "turnover-housekeeping", responseTarget: 15, escalation: 30 },
    { name: "Maintenance", code: "maintenance", responseTarget: 15, escalation: 30 },
    { name: "Safety & Escalation", code: "safety-escalation", responseTarget: 3, escalation: 5 }
  ];

  var defaultAreas = [
    { name: "Entrance / check-in", code: "entrance", type: "entrance", route: "guest-support", order: 10 },
    { name: "Living area", code: "living-area", type: "living", route: "guest-support", order: 20 },
    { name: "Kitchen", code: "kitchen", type: "kitchen", route: "maintenance", order: 30 },
    { name: "Bathroom", code: "bathroom", type: "bathroom", route: "maintenance", order: 40 },
    { name: "Bedroom", code: "bedroom", type: "bedroom", route: "turnover-housekeeping", order: 50 },
    { name: "Outdoor area", code: "outdoor-area", type: "outdoor", route: "maintenance", order: 60 },
    { name: "Parking", code: "parking", type: "parking", route: "guest-support", order: 70 },
    { name: "Whole property", code: "whole-property", type: "whole_property", route: "safety-escalation", order: 80 }
  ];

  function slugify(value) {
    return String(value || "")
      .normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
      .toLowerCase().replace(/&/g, " and ").replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "").slice(0, 80);
  }

  function findCategory(key) {
    return categories.filter(function (category) { return category.key === key; })[0] || null;
  }

  function flatten() {
    var rows = [];
    categories.forEach(function (category) {
      category.issues.forEach(function (label) {
        rows.push({
          categoryKey: category.key,
          categoryLabel: category.label,
          label: label,
          issueCode: category.key + ":" + slugify(label),
          emergency: Boolean(category.emergency)
        });
      });
    });
    return rows;
  }

  function search(query) {
    var terms = String(query || "").trim().toLowerCase().split(/\s+/).filter(Boolean);
    if (!terms.length) return [];
    return flatten().map(function (row) {
      var haystack = (row.label + " " + row.categoryLabel).toLowerCase();
      var score = terms.reduce(function (total, term) {
        if (row.label.toLowerCase().indexOf(term) === 0) return total + 5;
        if (row.label.toLowerCase().indexOf(term) >= 0) return total + 3;
        if (haystack.indexOf(term) >= 0) return total + 1;
        return total - 20;
      }, 0);
      return { row: row, score: score };
    }).filter(function (entry) { return entry.score >= 0; })
      .sort(function (a, b) { return b.score - a.score || a.row.label.localeCompare(b.row.label); })
      .map(function (entry) { return entry.row; });
  }

  global.InnRelayStaysCatalog = {
    vertical: "short_term_rental",
    categories: categories,
    departments: departments,
    defaultAreas: defaultAreas,
    findCategory: findCategory,
    flatten: flatten,
    search: search,
    slugify: slugify,
    stats: { categories: categories.length, issues: flatten().length }
  };
}(window));
