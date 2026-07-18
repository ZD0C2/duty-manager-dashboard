(function (global) {
  "use strict";

  var categories = [
    {
      key: "housekeeping-cleanliness",
      label: "Housekeeping & room cleanliness",
      group: "Room",
      audience: "both",
      issues: [
        "Room not cleaned", "Room cleaned late", "Daily service missed", "Requested clean not completed",
        "Do not disturb sign ignored", "Bed not made", "Dust on surfaces", "Dirty floor", "Carpet stained",
        "Carpet wet", "Hair found in room", "Hair found in bathroom", "Bathroom not cleaned", "Toilet not cleaned",
        "Shower or bath not cleaned", "Sink not cleaned", "Mirror marked", "Bin not emptied", "Rubbish left in room",
        "Bad smell in room", "Smoke smell", "Food smell", "Damp or mould smell", "Mould visible",
        "Insects or pest evidence", "Balcony or terrace dirty", "Window dirty", "Minibar area dirty",
        "Cleaning chemicals left behind", "Cleaning equipment left behind", "Personal item moved during cleaning",
        "Public corridor needs cleaning", "Stairwell needs cleaning", "Cleaning noise disturbing guest", "Deep clean required"
      ]
    },
    {
      key: "linen-towels-toiletries",
      label: "Linen, towels & toiletries",
      group: "Room",
      audience: "both",
      issues: [
        "Extra bath towels requested", "Extra hand towels requested", "Extra face cloths requested", "Fresh towels requested",
        "Towel missing", "Towel stained", "Towel damaged", "Towel damp on arrival", "Bath mat missing",
        "Bed linen stained", "Bed linen torn", "Bed linen damp", "Bed linen not changed", "Duvet cover missing",
        "Extra duvet requested", "Extra blanket requested", "Extra pillows requested", "Different pillow requested",
        "Pillowcase missing or stained", "Mattress protector issue", "Bathrobe requested", "Slippers requested",
        "Toilet roll missing", "Extra toilet roll requested", "Tissues missing", "Soap empty", "Shampoo empty",
        "Conditioner empty", "Body wash empty", "Hand wash empty", "Dental kit requested", "Shaving kit requested",
        "Sanitary products requested", "Shower cap requested", "Vanity kit requested", "Laundry bag requested"
      ]
    },
    {
      key: "bathroom-plumbing",
      label: "Bathroom, water & plumbing",
      group: "Room",
      audience: "both",
      issues: [
        "No hot water", "Hot water takes too long", "Water too hot", "Water temperature fluctuates",
        "Low water pressure", "No water", "Shower leaking", "Shower head damaged", "Shower hose damaged",
        "Shower controls not working", "Shower door not closing", "Bath leaking", "Bath plug missing or faulty",
        "Tap leaking", "Tap loose", "Sink blocked or draining slowly", "Bath blocked or draining slowly",
        "Shower drain blocked", "Drain smell", "Toilet not flushing", "Toilet blocked", "Toilet running continuously",
        "Toilet seat loose or damaged", "Bidet not working", "Bathroom extractor not working", "Bathroom flooding",
        "Water leak from ceiling", "Water leak from wall", "Pipe noise", "Bathroom sealant damaged",
        "Grab rail loose", "Bathroom door or lock faulty", "Towel rail not heating", "Bathroom floor slippery",
        "Water quality or colour concern"
      ]
    },
    {
      key: "heating-cooling-air",
      label: "Heating, cooling & air quality",
      group: "Room",
      audience: "both",
      issues: [
        "Room too hot", "Room too cold", "Air conditioning not cooling", "Air conditioning not heating",
        "Air conditioning not turning on", "Air conditioning noisy", "Air conditioning leaking", "Thermostat not working",
        "Radiator not heating", "Radiator too hot", "Radiator leaking", "Fan not working", "Ventilation poor",
        "Room feels stuffy", "Humidity too high", "Condensation", "Draft from window", "Draft from door",
        "Strong odour from ventilation", "Dust from air vent", "Air quality concern", "Portable heater requested",
        "Portable fan requested", "Window will not open", "Window will not close", "Climate control instructions needed"
      ]
    },
    {
      key: "electrical-lighting",
      label: "Electricity, lighting & charging",
      group: "Room",
      audience: "both",
      issues: [
        "No electricity in room", "Partial power loss", "Power keeps tripping", "Socket not working",
        "Socket loose or damaged", "USB charging point not working", "Bedside charging not working",
        "Main room light not working", "Bedside lamp not working", "Bathroom light not working",
        "Mirror light not working", "Wardrobe light not working", "Light flickering", "Light switch not working",
        "Lights will not turn off", "Lights too dim", "Emergency light fault", "Hairdryer not working",
        "Iron not working", "Kettle not working", "Coffee machine not working", "Electrical burning smell",
        "Electrical sparking", "Exposed wire or damaged cable", "Adapter requested", "Extension lead requested",
        "EV charging point problem"
      ]
    },
    {
      key: "room-furniture-fixtures",
      label: "Room furniture & fixtures",
      group: "Room",
      audience: "both",
      issues: [
        "Bed uncomfortable", "Mattress damaged", "Mattress too firm", "Mattress too soft", "Bed frame damaged",
        "Bed or headboard noisy", "Sofa bed problem", "Cot problem", "Chair damaged", "Desk damaged",
        "Bedside table damaged", "Wardrobe door faulty", "Wardrobe hanger missing", "Drawer faulty",
        "Curtain damaged", "Curtain will not close", "Blind damaged", "Blind will not close", "Window damaged",
        "Window seal damaged", "Mirror damaged", "Wall or paint damaged", "Ceiling damaged", "Floor damaged",
        "Carpet trip hazard", "Door stop damaged", "Balcony furniture damaged", "Balcony door faulty",
        "Minibar cabinet faulty", "Safe shelf or fitting damaged", "Luggage rack requested", "Furniture item missing",
        "Room layout obstructed", "Sharp edge or broken fitting"
      ]
    },
    {
      key: "wifi-tv-phone-technology",
      label: "Wi-Fi, TV, phone & room technology",
      group: "Technology",
      audience: "both",
      issues: [
        "Wi-Fi will not connect", "Wi-Fi password not working", "Wi-Fi very slow", "Wi-Fi keeps disconnecting",
        "Wi-Fi weak in room", "Internet outage", "Guest portal will not load", "TV will not turn on",
        "TV has no picture", "TV has no sound", "TV remote missing", "TV remote not working",
        "TV channels missing", "TV signal breaking up", "Casting or streaming not working", "HDMI input not working",
        "Hotel information screen incorrect", "Room telephone not working", "Room telephone has no dial tone",
        "Cannot call reception", "Voicemail light or message problem", "Alarm clock not working",
        "Wake-up call not received", "Smart-room controls not working", "Tablet or digital directory not working",
        "Bluetooth speaker not connecting", "Device charging station not working", "Technology instructions needed"
      ]
    },
    {
      key: "doors-keys-security",
      label: "Doors, keys, safe & room security",
      group: "Access & safety",
      audience: "both",
      issues: [
        "Key card not working", "Key card works intermittently", "Key card lost", "Mobile key not working",
        "Room door will not open", "Room door will not close", "Room door will not lock", "Door lock loose",
        "Door latch or chain damaged", "Door closer not working", "Peephole damaged or blocked",
        "Balcony door will not lock", "Window lock faulty", "Connecting door concern", "Safe will not open",
        "Safe will not lock", "Safe code forgotten", "Safe damaged", "Suspicious person near room",
        "Unauthorised entry concern", "Someone tried the room door", "Item may have been stolen",
        "Security escort requested", "Privacy concern", "CCTV question", "Master key concern",
        "Entrance door not secure", "Fire door not closing", "Emergency exit obstructed"
      ]
    },
    {
      key: "noise-disturbance",
      label: "Noise & disturbance",
      group: "Stay",
      audience: "both",
      issues: [
        "Noise from neighbouring room", "Loud music", "Loud television", "Party in room", "Shouting or arguing",
        "Corridor noise", "Door slamming", "Children running in corridor", "Noise from bar or restaurant",
        "Noise from event", "Street or traffic noise", "Construction noise", "Delivery noise", "Lift noise",
        "Plant or machinery noise", "Air conditioning noise", "Plumbing noise", "Cleaning noise",
        "Staff noise", "Dog barking", "Alarm sounding", "Repeated nuisance calls", "Guest disturbance or threatening behaviour",
        "Quiet-room move requested", "Earplugs requested"
      ]
    },
    {
      key: "reception-reservations-checkin",
      label: "Reception, reservation & check-in",
      group: "Guest services",
      audience: "both",
      issues: [
        "Reservation not found", "Reservation details incorrect", "Wrong room type", "Wrong bed type",
        "Number of guests incorrect", "Special request missing", "Accessible room request missing",
        "Connecting rooms request missing", "Early check-in request", "Late check-out request", "Room not ready",
        "Check-in queue too long", "Check-in taking too long", "Identity check question", "Deposit question",
        "Booking amendment requested", "Stay extension requested", "Room move requested", "Room upgrade requested",
        "Downgrade or room change concern", "No-show or cancellation dispute", "Third-party booking issue",
        "Loyalty benefit missing", "Welcome amenity missing", "Guest name incorrect", "Departure information requested",
        "Reception not answering", "Overbooking or relocation concern"
      ]
    },
    {
      key: "billing-payments-refunds",
      label: "Bill, payment, deposit & refund",
      group: "Guest services",
      audience: "both",
      issues: [
        "Charge not recognised", "Room rate incorrect", "Tax or fee question", "Duplicate charge", "Deposit charged incorrectly",
        "Deposit release pending", "Refund pending", "Refund amount incorrect", "Restaurant charge incorrect",
        "Bar charge incorrect", "Minibar charge disputed", "Parking charge incorrect", "Spa charge incorrect",
        "Extra-night charge incorrect", "No-show charge disputed", "Cancellation fee disputed", "Card payment declined",
        "Card machine not working", "Cash payment question", "Invoice requested", "Invoice details incorrect",
        "Company billing issue", "Split bill requested", "Receipt requested", "Currency conversion question",
        "Pre-authorisation question", "Payment link problem", "Voucher or gift card not accepted", "Service charge question"
      ]
    },
    {
      key: "guest-service-requests",
      label: "Guest service & room requests",
      group: "Guest services",
      audience: "both",
      issues: [
        "Wake-up call requested", "Luggage assistance requested", "Luggage storage requested", "Ice requested",
        "Drinking water requested", "Extra cups or glasses requested", "Tea or coffee supplies requested",
        "Milk requested", "Room directory or hotel information requested", "Local information requested",
        "Restaurant recommendation requested", "Taxi requested", "Print or copy requested", "Parcel collection requested",
        "Message delivery requested", "Maintenance visit requested", "Housekeeping visit requested",
        "Privacy or no-service request", "Celebration setup requested", "Birthday or anniversary request",
        "Prayer mat requested", "Sewing kit requested", "Umbrella requested", "Phone charger requested",
        "Scales requested", "First-aid item requested", "Guest wants to speak to a manager"
      ]
    },
    {
      key: "breakfast",
      label: "Breakfast",
      group: "Food & drink",
      audience: "both",
      issues: [
        "Breakfast opening time question", "Breakfast location question", "Breakfast not included", "Breakfast charge incorrect",
        "Breakfast queue too long", "Table not available", "Table not clean", "Breakfast item unavailable",
        "Hot food cold", "Food overcooked", "Food undercooked", "Food quality concern", "Coffee cold",
        "Coffee machine fault", "Tea supplies missing", "Juice unavailable", "Milk unavailable",
        "Cutlery missing or dirty", "Plate or bowl dirty", "Chipped plate or cup", "Glass dirty",
        "Condiments missing", "High chair requested", "Dietary option unavailable", "Allergen information requested",
        "Takeaway breakfast requested", "Early breakfast requested", "Breakfast service slow", "Breakfast staff concern"
      ]
    },
    {
      key: "restaurant-room-service",
      label: "Restaurant & room service",
      group: "Food & drink",
      audience: "both",
      issues: [
        "Restaurant reservation requested", "Restaurant reservation missing", "Table not ready", "Restaurant queue too long",
        "Order not taken", "Order taking too long", "Food delivery taking too long", "Wrong dish delivered",
        "Item missing from order", "Food cold", "Food overcooked", "Food undercooked", "Food quality concern",
        "Portion concern", "Menu item unavailable", "Room service menu missing", "Room service not answering",
        "Room service tray not collected", "Cutlery missing", "Napkins missing", "Condiments missing",
        "Table or tray dirty", "Chipped crockery", "Bill incorrect", "Service charge question", "Restaurant staff concern",
        "Private dining request", "Child meal requested", "Dietary meal requested"
      ]
    },
    {
      key: "bar-beverages",
      label: "Bar & beverages",
      group: "Food & drink",
      audience: "both",
      issues: [
        "Bar opening time question", "Bar closed unexpectedly", "Waiting too long at bar", "Drink order delayed",
        "Wrong drink served", "Drink quality concern", "Beer tastes unusual", "Beer temperature concern",
        "Wine temperature concern", "Coffee quality concern", "Coffee machine fault", "Drink unavailable",
        "Ice unavailable", "Glass dirty", "Glass chipped", "Table dirty", "Bar area untidy",
        "Bill incorrect", "Card payment problem", "Alcohol-free option requested", "Bar snack unavailable",
        "Noise from bar", "Bar staff concern", "Possible intoxication concern", "Suspected drink tampering"
      ]
    },
    {
      key: "food-allergy-dietary-safety",
      label: "Food allergy, dietary need & food safety",
      group: "Food & drink",
      audience: "both",
      issues: [
        "Allergen information requested", "Allergy not recorded", "Allergy request not followed",
        "Possible allergic reaction", "Cross-contamination concern", "Food labelling concern", "Undercooked food safety concern",
        "Foreign object in food", "Food appears spoiled", "Food smells unusual", "Food temperature safety concern",
        "Vegan option requested", "Vegetarian option requested", "Gluten-free option requested", "Dairy-free option requested",
        "Halal option requested", "Kosher option requested", "Nut-free option requested", "Low-salt option requested",
        "Diabetic-friendly option requested", "Texture-modified meal requested", "Baby food heating requested",
        "Dietary request unavailable", "Kitchen hygiene concern", "Suspected food poisoning"
      ]
    },
    {
      key: "minibar-vending-retail",
      label: "Minibar, vending & hotel shop",
      group: "Food & drink",
      audience: "both",
      issues: [
        "Minibar empty", "Minibar item missing", "Minibar item expired", "Minibar not cooling", "Minibar noisy",
        "Minibar charge disputed", "Minibar price question", "Vending machine out of order", "Vending machine not accepting payment",
        "Vending machine kept money", "Vending item stuck", "Vending item out of stock", "Vending item expired",
        "Ice machine out of order", "Water dispenser out of order", "Hotel shop closed", "Shop item unavailable",
        "Shop price or payment issue", "Bottle opener requested", "Fridge requested for medication"
      ]
    },
    {
      key: "public-areas-lifts",
      label: "Public areas, corridors, stairs & lifts",
      group: "Property",
      audience: "both",
      issues: [
        "Lift out of service", "Lift delayed", "Lift stopped unexpectedly", "Lift door problem", "Lift alarm concern",
        "Escalator problem", "Corridor dirty", "Corridor obstruction", "Corridor lighting fault", "Stairwell lighting fault",
        "Stair or handrail damaged", "Floor wet or slippery", "Trip hazard", "Public toilet dirty", "Public toilet blocked",
        "Public toilet supplies missing", "Lobby seating unavailable", "Lobby too hot or cold", "Lobby noise",
        "Entrance door problem", "Revolving door problem", "Signage unclear or missing", "Wayfinding assistance requested",
        "Smoking in non-smoking area", "Public area furniture damaged", "Ceiling leak in public area"
      ]
    },
    {
      key: "parking-arrival-transport",
      label: "Parking, arrival & transport",
      group: "Arrival",
      audience: "both",
      issues: [
        "Hotel entrance difficult to find", "Parking location question", "Parking full", "Parking space unavailable",
        "Accessible parking unavailable", "Parking barrier not working", "Parking ticket or validation problem",
        "Parking charge question", "Vehicle damage concern", "Vehicle security concern", "EV charger not working",
        "Valet service delayed", "Valet vehicle retrieval issue", "Taxi requested", "Taxi delayed or missing",
        "Airport transfer requested", "Transfer delayed or missing", "Shuttle information requested", "Shuttle full",
        "Drop-off area blocked", "Luggage unloading assistance requested", "Coach parking issue", "Bicycle storage requested",
        "Motorcycle parking requested", "Directions requested"
      ]
    },
    {
      key: "accessibility-mobility",
      label: "Accessibility & mobility",
      group: "Access & safety",
      audience: "both",
      issues: [
        "Step-free route unavailable", "Accessible entrance problem", "Accessible parking unavailable",
        "Accessible room not prepared", "Accessible room feature missing", "Wheelchair route obstructed",
        "Lift unavailable affects access", "Ramp damaged or too steep", "Grab rail loose or missing",
        "Shower chair requested", "Raised toilet seat requested", "Portable ramp requested", "Wheelchair requested",
        "Mobility scooter storage requested", "Hearing loop not working", "Visual alarm concern", "Braille signage missing",
        "Large-print information requested", "Sign-language support requested", "Quiet check-in requested",
        "Assistance animal concern", "Accessible table unavailable", "Evacuation assistance plan needed",
        "Carer or companion room issue", "Medication refrigeration requested"
      ]
    },
    {
      key: "family-children",
      label: "Family, baby & children",
      group: "Guest services",
      audience: "both",
      issues: [
        "Cot requested", "Cot missing", "Cot damaged or unsafe", "Extra bed requested", "Extra bed missing",
        "High chair requested", "Baby bath requested", "Bottle warming requested", "Baby food heating requested",
        "Nappy bin requested", "Changing facility question", "Childproofing request", "Connecting rooms request",
        "Children's menu requested", "Children's activity information requested", "Child lost or separated",
        "Baby monitor question", "Family room setup incorrect", "Child bedding missing", "Pool child-safety concern",
        "Babysitting information requested", "Pushchair storage requested"
      ]
    },
    {
      key: "pets-assistance-animals",
      label: "Pets & assistance animals",
      group: "Guest services",
      audience: "both",
      issues: [
        "Pet policy question", "Pet fee question", "Pet-friendly room not prepared", "Pet bed requested",
        "Pet bowl requested", "Pet waste bags requested", "Pet cleaning concern", "Pet noise complaint",
        "Pet left unattended", "Pet damage concern", "Pet relief area question", "Assistance animal access concern",
        "Assistance animal room setup", "Pet allergy room concern", "Veterinary information requested"
      ]
    },
    {
      key: "laundry-dry-cleaning",
      label: "Laundry, ironing & dry cleaning",
      group: "Guest services",
      audience: "both",
      issues: [
        "Laundry collection requested", "Laundry not collected", "Laundry delayed", "Laundry item missing",
        "Laundry item damaged", "Laundry returned stained", "Laundry charge incorrect", "Laundry form missing",
        "Laundry bag missing", "Dry-cleaning request", "Dry cleaning delayed", "Iron requested", "Iron damaged",
        "Ironing board requested", "Ironing board damaged", "Self-service laundry question", "Washing machine out of order",
        "Dryer out of order", "Detergent unavailable", "Clothes drying request"
      ]
    },
    {
      key: "lost-property-deliveries",
      label: "Lost property, parcels & deliveries",
      group: "Guest services",
      audience: "both",
      issues: [
        "Item lost in room", "Item lost in public area", "Item left after checkout", "Lost item search update requested",
        "Found item to hand in", "Lost property return requested", "Courier collection requested", "Parcel expected",
        "Parcel not found", "Parcel delivered to wrong guest", "Food delivery arrival question", "Food delivery not allowed upstairs",
        "Flower delivery expected", "Luggage delivery delayed", "Mail or letter expected", "Secure item storage requested",
        "Passport or identity document lost", "Phone or device lost", "Room key lost", "Vehicle key lost"
      ]
    },
    {
      key: "meetings-events-business",
      label: "Meetings, events & business services",
      group: "Events",
      audience: "both",
      issues: [
        "Meeting room not ready", "Meeting room locked", "Room layout incorrect", "Chairs or tables missing",
        "Projector not working", "Display screen not working", "HDMI or adapter missing", "Microphone not working",
        "Sound system not working", "Video conference not working", "Event Wi-Fi problem", "Power socket problem",
        "Lighting problem", "Room too hot or cold", "Catering delayed", "Catering item missing",
        "Dietary requirement missed", "Water or refreshments missing", "Flipchart or stationery missing",
        "Printing requested", "Business centre equipment fault", "Event signage missing", "Delegate registration issue",
        "Event noise complaint", "Private event access concern", "Invoice or event billing issue", "Wedding or celebration setup issue"
      ]
    },
    {
      key: "spa-gym-pool-leisure",
      label: "Spa, gym, pool & leisure",
      group: "Leisure",
      audience: "both",
      issues: [
        "Spa booking requested", "Spa booking missing", "Spa treatment delayed", "Treatment concern",
        "Changing room dirty", "Locker not working", "Towel unavailable", "Robe or slippers unavailable",
        "Pool closed", "Pool temperature concern", "Pool cleanliness concern", "Pool safety concern",
        "Sauna not working", "Steam room not working", "Hot tub not working", "Gym closed",
        "Gym equipment out of order", "Gym equipment unsafe", "Gym cleanliness concern", "Water station empty",
        "Leisure area too hot or cold", "Noise in leisure area", "Class booking issue", "Age restriction question",
        "Accessibility problem in leisure area", "Spa or leisure charge incorrect"
      ]
    },
    {
      key: "outdoor-grounds-smoking",
      label: "Outdoor areas, grounds & smoking",
      group: "Property",
      audience: "both",
      issues: [
        "Outdoor area dirty", "Terrace table dirty", "Outdoor furniture damaged", "Garden lighting fault",
        "Path obstructed", "Path slippery or icy", "Uneven paving or trip hazard", "Flooding outside",
        "Smoking area location question", "Smoking outside designated area", "Cigarette smoke entering room",
        "Ashtray overflowing", "Noise from outdoor area", "Outdoor heater not working", "Outdoor area closed",
        "Gate or fence damaged", "Poor external signage", "Snow or ice clearance needed", "Animal or bird nuisance"
      ]
    },
    {
      key: "staff-service-recovery",
      label: "Staff service, conduct & complaint",
      group: "Guest services",
      audience: "both",
      issues: [
        "Staff member was helpful - compliment", "Guest felt unwelcome", "Staff member was rude", "Staff communication unclear",
        "Request was ignored", "Request was forgotten", "Promised callback not received", "Complaint follow-up delayed",
        "No ownership of issue", "Conflicting information provided", "Privacy concern involving staff",
        "Discrimination concern", "Harassment concern", "Language support needed", "Manager requested",
        "Service recovery offer not delivered", "Compensation or goodwill request", "Complaint about contractor",
        "Complaint about another guest handling", "General complaint", "General compliment or feedback"
      ]
    },
    {
      key: "medical-safety-emergency",
      label: "Medical, fire, safety or emergency",
      group: "Access & safety",
      audience: "both",
      emergency: true,
      issues: [
        "Medical emergency", "Guest injury", "Guest feeling unwell", "Allergic reaction", "Suspected food poisoning",
        "Fire or smoke seen", "Fire alarm sounding", "Burning smell", "Gas smell", "Carbon monoxide alarm",
        "Flooding or major water leak", "Electrical sparking or fire risk", "Person trapped in lift",
        "Missing child or vulnerable person", "Threatening or violent behaviour", "Domestic abuse concern",
        "Suspected theft in progress", "Suspicious package", "Weapon concern", "Drug-related concern",
        "Self-harm or welfare concern", "Guest cannot be contacted and welfare check needed", "Slip, trip or fall",
        "Unsafe balcony or window", "Blocked fire exit", "Emergency exit door fault", "Evacuation assistance needed",
        "First aid requested", "Police requested", "Ambulance requested", "Fire service requested"
      ]
    },
    {
      key: "pest-hygiene-environment",
      label: "Pest, hygiene & environmental concern",
      group: "Property",
      audience: "both",
      issues: [
        "Bedbug concern", "Cockroach sighting", "Rodent sighting", "Ants in room", "Flies or insects",
        "Mosquito concern", "Bird inside building", "Pest evidence or droppings", "Bite or sting concern",
        "Mould visible", "Damp patch", "Sewage smell", "Waste smell", "Overflowing rubbish",
        "Needle or sharp object found", "Bodily fluid contamination", "Biohazard concern", "Water quality concern",
        "Legionella or water hygiene concern", "Chemical smell", "Chemical spill", "Air pollution or smoke concern",
        "Excessive dust", "Food waste hygiene concern"
      ]
    },
    {
      key: "sustainability-waste",
      label: "Sustainability, recycling & waste",
      group: "Property",
      audience: "both",
      issues: [
        "Recycling information requested", "Recycling bin missing", "Waste not collected", "Bin overflowing",
        "Food waste concern", "Water leak or waste", "Lights left on", "Heating or cooling waste concern",
        "Towel reuse request not followed", "Linen reuse request not followed", "Single-use plastic concern",
        "Electric vehicle charging question", "Bicycle facility question", "Sustainability policy question",
        "Noise or light pollution concern", "Environmental complaint or suggestion"
      ]
    },
    {
      key: "building-maintenance",
      label: "Building, maintenance & structural issue",
      group: "Operations",
      audience: "staff",
      issues: [
        "Roof leak", "Ceiling leak", "Burst pipe", "Major water ingress", "Wall crack", "Ceiling crack",
        "Loose tile", "Damaged flooring", "Broken window", "Damaged glazing", "Door frame damaged",
        "Ceiling panel loose", "External cladding concern", "Drain or gutter blocked", "Sewage backup",
        "Boiler fault", "Hot-water plant fault", "HVAC plant fault", "Pump fault", "Generator fault",
        "Building management system alarm", "Plant room alarm", "Gas supply fault", "Water supply fault",
        "Contractor visit overdue", "Preventive maintenance overdue", "Room requires out-of-order status",
        "Area requires isolation", "Structural safety concern"
      ]
    },
    {
      key: "kitchen-food-operations",
      label: "Kitchen & food operations",
      group: "Operations",
      audience: "staff",
      issues: [
        "Fridge temperature out of range", "Freezer temperature out of range", "Hot-hold temperature out of range",
        "Chilled delivery temperature out of range", "Food probe missing or faulty", "Temperature record missed",
        "Fridge or freezer door not sealing", "Kitchen equipment out of order", "Dishwasher fault", "Extraction fault",
        "Grease trap issue", "Food stock unavailable", "Food stock low", "Food item expired", "Incorrect date label",
        "Allergen matrix out of date", "Allergen briefing gap", "Cross-contamination risk", "Cleaning schedule missed",
        "Pest evidence in kitchen", "Waste collection overdue", "Broken or chipped crockery", "Cutlery not polished",
        "Glassware not clean", "Breakfast setup incomplete", "Delivery missing or incorrect", "Supplier quality issue",
        "Beer line cleaning overdue", "Beer nozzle cleaning missed", "Beer container cleaning issue"
      ]
    },
    {
      key: "stock-supplies",
      label: "Stock, supplies & purchasing",
      group: "Operations",
      audience: "staff",
      issues: [
        "Housekeeping stock low", "Housekeeping stock unavailable", "Linen stock low", "Towel stock low",
        "Toiletry stock low", "Cleaning chemical stock low", "Reception stationery low", "Key-card stock low",
        "Breakfast stock low", "Restaurant stock low", "Bar stock low", "Vending stock low", "Minibar stock low",
        "Maintenance spare part unavailable", "First-aid stock low", "Fire-safety consumable missing",
        "Delivery overdue", "Delivery short", "Delivery damaged", "Wrong item delivered", "Purchase order issue",
        "Supplier unavailable", "Stock count variance", "Stock item expired", "Storage area disorganised",
        "Cold storage capacity issue", "Secure storage issue"
      ]
    },
    {
      key: "cash-pos-financial",
      label: "Cash, tills, POS & financial control",
      group: "Operations",
      audience: "staff",
      issues: [
        "Till below target float", "Till count variance", "Cash-up variance", "Cash drop not completed",
        "Cash pod number missing", "Cash pod colour missing", "Cash pod unavailable", "Safe access problem",
        "Safe count variance", "Petty cash variance", "Card machine offline", "Card machine paper low",
        "POS terminal offline", "POS order not printing", "Payment posted to wrong room", "Refund pending approval",
        "Chargeback received", "Invoice posting problem", "Night audit imbalance", "Revenue report mismatch",
        "Cash collection delayed", "Suspicious or counterfeit note", "Receipt printer fault", "Manager approval required"
      ]
    },
    {
      key: "hotel-systems-it",
      label: "Hotel systems, IT & communications",
      group: "Operations",
      audience: "staff",
      issues: [
        "PMS not responding", "PMS login problem", "PMS interface not updating", "Reservation channel not syncing",
        "OTA booking not received", "Rate or availability mismatch", "Door-lock encoder fault", "Key-card system outage",
        "Staff Wi-Fi outage", "Hotel internet outage", "Network equipment alarm", "Telephone system outage",
        "Reception phone fault", "Radio or walkie-talkie fault", "Printer not working", "Scanner not working",
        "Email unavailable", "Shared drive unavailable", "Staff tablet fault", "Staff mobile device fault",
        "CCTV system fault", "Access-control system fault", "Sound system fault", "Digital signage fault",
        "Guest messaging not sending", "Data export or backup failed", "Cybersecurity concern", "Suspected phishing email",
        "Account access or password problem"
      ]
    },
    {
      key: "fire-life-safety-compliance",
      label: "Fire, life safety & compliance",
      group: "Operations",
      audience: "staff",
      emergency: true,
      issues: [
        "Fire alarm activation", "Fire panel fault", "Fire detector fault", "Manual call point fault",
        "Fire alarm test overdue", "Fire walk missed", "Fire exit obstructed", "Fire door propped open",
        "Fire door not closing", "Emergency lighting fault", "Exit sign damaged", "Extinguisher missing or damaged",
        "Fire blanket missing or damaged", "Sprinkler concern", "Smoke-control system fault", "Evacuation chair missing or faulty",
        "Evacuation plan unavailable", "Guest evacuation assistance not recorded", "First-aid kit incomplete",
        "Accident report required", "RIDDOR review required", "COSHH record issue", "Risk assessment overdue",
        "Safety inspection overdue", "Licence or certificate expiry", "Pool safety check missed", "Security patrol missed",
        "Lone-worker check missed", "Emergency contact list out of date"
      ]
    },
    {
      key: "security-incident",
      label: "Security incident & safeguarding",
      group: "Operations",
      audience: "staff",
      emergency: true,
      issues: [
        "Unauthorised person on property", "Aggressive or violent person", "Domestic abuse concern", "Child safeguarding concern",
        "Vulnerable adult concern", "Missing person", "Welfare check required", "Theft reported", "Burglary concern",
        "Fraud or payment concern", "Drug use or dealing concern", "Weapon concern", "Suspicious package",
        "Bomb threat", "Police attendance", "Ambulance attendance", "Fire service attendance", "Guest ejection required",
        "Banned guest identified", "Room occupancy concern", "Human trafficking concern", "Modern slavery concern",
        "CCTV footage request", "Master key lost", "Staff key lost", "Data or privacy incident", "Noise escalation required",
        "Night entrance control problem"
      ]
    },
    {
      key: "staffing-operations",
      label: "Staffing, shift & operational continuity",
      group: "Operations",
      audience: "staff",
      issues: [
        "Shift handover incomplete", "Open issue has no owner", "Guest callback overdue", "Scheduled shift check missed",
        "End-of-shift process delayed", "Staff absence", "Shift understaffed", "Agency staff required",
        "Department cover unavailable", "Training gap identified", "Uniform or PPE unavailable", "Radio not issued",
        "Staff meal issue", "Break cover problem", "Contractor late or absent", "Manager escalation required",
        "Daily briefing missed", "VIP or special-arrival briefing missed", "Group arrival plan incomplete",
        "Event staffing issue", "Housekeeping room-release delay", "Maintenance response delay", "Reception queue escalation",
        "Guest recovery action overdue", "Policy or procedure unclear"
      ]
    }
  ];

  function slugify(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/&/g, "and")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 80);
  }

  var shortTermRentalCategories = [
    {
      key: "str-checkin-access",
      label: "Check-in, keys & access",
      group: "Short-term rental",
      audience: "both",
      verticals: ["short_term_rental"],
      issues: [
        "Cannot find the property", "Check-in instructions unclear", "Lockbox code not working", "Smart lock not working",
        "Key missing", "Key broken", "Door will not open", "Door will not lock", "Gate or building entry problem",
        "Parking access problem", "Intercom not working", "Lift access problem", "Wrong access code supplied",
        "Guest locked out", "Late check-in help requested", "Checkout instructions unclear", "Luggage drop-off question"
      ]
    },
    {
      key: "str-kitchen-appliances",
      label: "Kitchen, appliances & supplies",
      group: "Short-term rental",
      audience: "both",
      verticals: ["short_term_rental"],
      issues: [
        "Oven not working", "Hob not working", "Microwave not working", "Fridge not cooling", "Freezer not freezing",
        "Dishwasher not working", "Washing machine not working", "Dryer not working", "Kettle not working",
        "Coffee machine not working", "Cookware missing", "Cutlery missing", "Plates or glasses missing",
        "Chipped crockery", "Bin bags missing", "Washing-up liquid missing", "Kitchen not clean",
        "Bad smell from fridge", "Kitchen sink blocked", "Extractor fan not working"
      ]
    },
    {
      key: "str-bathroom-water",
      label: "Bathroom, water & toiletries",
      group: "Short-term rental",
      audience: "both",
      verticals: ["short_term_rental"],
      issues: [
        "No hot water", "Low water pressure", "Shower not working", "Shower leaking", "Bath blocked",
        "Toilet blocked", "Toilet not flushing", "Sink blocked", "Water leak", "Bathroom flooding",
        "Towels missing", "Toilet roll missing", "Soap or shampoo missing", "Bathroom not clean",
        "Mould visible", "Extractor fan not working", "Bathroom door lock problem", "Slippery bathroom floor"
      ]
    },
    {
      key: "str-bedroom-linen-comfort",
      label: "Bedroom, linen & comfort",
      group: "Short-term rental",
      audience: "both",
      verticals: ["short_term_rental"],
      issues: [
        "Bed linen missing", "Bed linen stained", "Extra bedding requested", "Pillow missing",
        "Extra pillow requested", "Blanket requested", "Mattress uncomfortable", "Sofa bed problem",
        "Cot or travel cot issue", "Bedroom not clean", "Wardrobe or hanger problem", "Curtains or blinds problem",
        "Noise disturbing sleep", "Heating too low", "Room too hot", "Fan requested"
      ]
    },
    {
      key: "str-wifi-tv-technology",
      label: "Wi-Fi, TV & smart-home",
      group: "Short-term rental",
      audience: "both",
      verticals: ["short_term_rental"],
      issues: [
        "Wi-Fi will not connect", "Wi-Fi password not working", "Wi-Fi slow", "Router offline",
        "TV not working", "Remote missing", "Streaming app problem", "Speaker or sound problem",
        "Thermostat not working", "Smart lighting not working", "Security alarm issue", "Doorbell camera question",
        "Appliance instructions needed", "Power socket not working", "Power outage"
      ]
    },
    {
      key: "str-cleaning-maintenance",
      label: "Cleaning, damage & maintenance",
      group: "Short-term rental",
      audience: "both",
      verticals: ["short_term_rental"],
      issues: [
        "Property not cleaned", "Rubbish left behind", "Bad smell", "Pest or insect sighting",
        "Broken furniture", "Damaged wall or floor", "Broken window", "Heating not working",
        "Air conditioning not working", "Smoke alarm beeping", "Carbon monoxide alarm concern",
        "Light not working", "Leak or damp patch", "Outdoor area dirty", "Pool or hot tub problem",
        "Garden or balcony issue"
      ]
    },
    {
      key: "str-house-rules-neighbours",
      label: "House rules, neighbours & safety",
      group: "Short-term rental",
      audience: "both",
      verticals: ["short_term_rental"],
      issues: [
        "Noise complaint", "Neighbour concern", "Parking dispute", "Bins or recycling question",
        "Smoking smell", "Party or disturbance nearby", "Lost item", "Suspicious person",
        "Safety concern", "Fire or smoke concern", "Medical emergency", "Guest wants host to call",
        "House rule clarification", "Pet policy question", "Extra guest question"
      ]
    }
  ];

  shortTermRentalCategories.forEach(function (category) { categories.push(category); });

  function categoryMatchesVertical(category, vertical) {
    var chosen = vertical || "hotel";
    var allowed = category.verticals || ["hotel"];
    return allowed.indexOf(chosen) > -1 || allowed.indexOf("all") > -1;
  }

  function flatten(options) {
    var audience = options && options.audience;
    var vertical = options && options.vertical;
    var rows = [];
    categories.forEach(function (category) {
      if (audience === "guest" && category.audience === "staff") return;
      if (vertical && !categoryMatchesVertical(category, vertical)) return;
      category.issues.forEach(function (issue) {
        rows.push({
          code: category.key + ":" + slugify(issue),
          label: issue,
          categoryKey: category.key,
          categoryLabel: category.label,
          group: category.group,
          audience: category.audience,
          emergency: Boolean(category.emergency)
        });
      });
    });
    return rows;
  }

  function toIssueLibrary(options) {
    var guestOnly = options && options.guestOnly;
    var vertical = options && options.vertical;
    var result = {};
    categories.forEach(function (category) {
      if (guestOnly && category.audience === "staff") return;
      if (vertical && !categoryMatchesVertical(category, vertical)) return;
      result[category.label] = category.issues.slice().concat(["Other / something else"]);
    });
    return result;
  }

  function search(query, options) {
    var term = String(query || "").trim().toLowerCase();
    var rows = flatten(options);
    if (!term) return rows;
    return rows.filter(function (row) {
      return [row.label, row.categoryLabel, row.group].join(" ").toLowerCase().indexOf(term) > -1;
    });
  }

  var allIssues = flatten();
  var guestIssues = flatten({ audience: "guest" });

  global.InnRelayCatalog = {
    version: "2026.07.13",
    categories: categories,
    guestCategories: categories.filter(function (category) { return category.audience !== "staff"; }),
    guestCategoriesForVertical: function (vertical) {
      return categories.filter(function (category) {
        return category.audience !== "staff" && categoryMatchesVertical(category, vertical || "hotel");
      });
    },
    slugify: slugify,
    flatten: flatten,
    search: search,
    toIssueLibrary: toIssueLibrary,
    stats: {
      categories: categories.length,
      issues: allIssues.length,
      guestCategories: categories.filter(function (category) { return category.audience !== "staff"; }).length,
      guestIssues: guestIssues.length
    }
  };
}(window));
