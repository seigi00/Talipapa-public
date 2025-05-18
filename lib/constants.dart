// Contains color constants and commodity list 
import 'package:flutter/material.dart';

const kGreen = Color(0xFFD1EE64);
const kBlue = Color(0xFF042F80);
const kPink = Color(0xFFF18496);
const kLightGray = Color(0xFFF9F9F9);
const kAltGray = Color(0xFFF7F7F7);
const kDivider = Color(0xFFEDEDED);

//darkmode
const kDarkAltGray = Color.fromARGB(255, 42, 54, 77);

// Commodity Types and Items
const COMMODITY_TYPES = {
  'Kadiwa Rice-for-all': [
    {'name': 'Well milled', 'id': '85'},
  ],
  'Imported Commercial Rice': [
    {'name': 'Special', 'id': '55'},
    {'name': 'Premium', 'id': '53'},
    {'name': 'Well milled', 'id': '56'},
    {'name': 'Regular milled', 'id': '54'},
  ],
  'Local Commercial Rice': [
    {'name': 'Special', 'id': '62'},
    {'name': 'Premium', 'id': '60'},
    {'name': 'Well milled', 'id': '63'},
    {'name': 'Regular milled', 'id': '61'},
  ],
  'Corn': [
    {'name': 'Corn (White)', 'id': '38'},
    {'name': 'Corn (Yellow)', 'id': '39'},
    {'name': 'Corn Grits (White, Food Grade)', 'id': '42'},
    {'name': 'Corn Grits (Yellow, Food Grade)', 'id': '43'},
    {'name': 'Corn Cracked (Yellow, Feed Grade)', 'id': '40'},
    {'name': 'Corn Grits (Feed Grade)', 'id': '41'},
  ],
  'Fish': [
    {'name': 'Bangus | Specification: Large', 'id': '7'},
    {'name': 'Bangus | Specification: Medium(3-4pcs/kg)', 'id': '8'},
    {'name': 'Tilapia', 'id': '82'},
    {'name': 'Galunggong (Local)', 'id': '48'},
    {'name': 'Galunggong (Imported)', 'id': '47'},
    {'name': 'Alumahan', 'id': '1'},
    {'name': 'Bonito', 'id': '13'},
    {'name': 'Salmon Head', 'id': '74'},
    {'name': 'Sardines (Tamban)', 'id': '75'},
    {'name': 'Squid (Pusit Bisaya)', 'id': '78'},
    {'name': 'Yellow-Fin Tuna (Tambakol)', 'id': '90'},
  ],
  'Livestock & Poultry Products': [
    'Beef Rump',
    'Beef Brisket',
    'Pork Ham',
    'Pork Belly',
    'Frozen Kasim',
    'Frozen Liempo',
    'Whole Chicken',
    'Chicken Egg (White, Pewee)',
    'Chicken Egg (White, Extra Small)',
    'Chicken Egg (White, Small)',
    'Chicken Egg (White, Medium)',
    'Chicken Egg (White, Large)',
    'Chicken Egg (White, Extra Large)',
    'Chicken Egg (White, Jumbo)',
    'Chicken Egg (Brown, Medium)',
    'Chicken Egg (Brown, Large)',
    'Chicken Egg (Brown, Extra Large)'
  ],
  'Lowland Vegetables': [
    'Ampalaya',
    'Sitao',
    'Pechay (Native)',
    'Squash',
    'Eggplant',
    'Tomato'
  ],
  'Highland Vegetables': [
    'Bell Pepper (Green)',
    'Bell Pepper (Red)',
    'Broccoli',
    'Cabbage (Rare Ball)',
    'Cabbage (Scorpio)',
    'Cabbage (Wonder Ball)',
    'Carrots',
    'Habi chuelas (Baguio Beans)',
    'White Potato',
    'Pechay (Baguio)',
    'Chayote',
    'Cauliflower',
    'Celery',
    'Lettuce (Green Ice)',
    'Lettuce (Iceberg)',
    'Lettuce (Romaine)'
  ],
  'Spices': [
    'Red Onion',
    'Red Onion (Imported)',
    'White Onion',
    'White Onion (Imported)',
    'Garlic (Imported)',
    'Garlic (Native)',
    'Ginger',
    'Chili (Red)'
  ],
  'Fruits': [
    'Calamansi',
    'Banana (Lakatan)',
    'Banana (Latundan)',
    'Banana (Saba)',
    'Papaya',
    'Mango (Carabao)',
    'Avocado',
    'Melon',
    'Pomelo',
    'Watermelon'
  ],
  'Other Basic Commodities': [
    'Sugar (Refined)',
    'Sugar (Washed)',
    'Sugar (Brown)',
    'Cooking Oil (Palm) | Spec: 350 ml/bottle',
    'Cooking Oil (Palm) | Spec: 1 liter/bottle',
    'Cooking Oil (Coconut)'
  ],
};

// Commodity display mapping (UUID-based)
// Update COMMODITY_ID_TO_DISPLAY to use the category directly (no separate type field)

// Categories in original order
const List<String> COMMODITY_CATEGORIES = [
  'Kadiwa Rice-for-all',
  'Imported Commercial Rice',
  'Local Commercial Rice',
  'Corn',
  'Fish',
  'Livestock & Poultry Products',
  'Lowland Vegetables',
  'Highland Vegetables',
  'Spices',
  'Fruits',
  'Other Basic Commodities',
];

// Updated mapping with category instead of type, and added units
const Map<String, Map<String, String>> COMMODITY_ID_TO_DISPLAY = {
  // Kadiwa Rice-for-all
  "26827a44-138a-42fe-9ee9-174cfe666f10": {
    "display_name": "Well milled",
    "category": "Kadiwa Rice-for-all",
    "specification": "1-19% bran steak",
    "unit": "kg"
  },
  
  // Imported Commercial Rice
  "aaa3c4ce-9580-4626-8513-6aae84418d80": {
    "display_name": "Special",
    "category": "Imported Commercial Rice",
    "specification": "white rice",
    "unit": "kg"
  },
  "d2536507-95dd-488e-8cd0-4ab7a07cd0b6": {
    "display_name": "Premium",
    "category": "Imported Commercial Rice",
    "specification": "5% broken",
    "unit": "kg"
  },
  "2b53a118-29a5-4998-9603-ced55a337442": {
    "display_name": "Well milled",
    "category": "Imported Commercial Rice",
    "specification": "1-19% bran steak",
    "unit": "kg"
  },
  "4cda9267-860a-4b98-8466-e63ab29f42ee": {
    "display_name": "Regular milled",
    "category": "Imported Commercial Rice",
    "specification": "20-40% bran steak",
    "unit": "kg"
  },
  
  // Local Commercial Rice
  "8b108f67-71dd-471b-ac60-c347d938e1af": {
    "display_name": "Special",
    "category": "Local Commercial Rice",
    "specification": "White Rice",
    "unit": "kg"
  },
  "ca2dc874-14c1-447a-bcde-f3265dd65437": {
    "display_name": "Premium",
    "category": "Local Commercial Rice",
    "specification": "5% broken",
    "unit": "kg"
  },
  "7938c518-e97e-4423-bdbb-3de173cb5203": {
    "display_name": "Well milled",
    "category": "Local Commercial Rice",
    "specification": "1-19% bran steak",
    "unit": "kg"
  },
  "421f1f15-9be7-4d0c-a0eb-9cbbe901f33f": {
    "display_name": "Regular milled",
    "category": "Local Commercial Rice",
    "specification": "20-40% bran steak",
    "unit": "kg"
  },
  
  // Corn
  "61da9ee5-9734-40d9-bc41-1dd31714469e": {
    "display_name": "Corn (White)",
    "category": "Corn",
    "specification": "Cob, Glutinous",
    "unit": "kg"
  },
  "50eb8bbd-c1da-492a-a258-e057045b0baa": {
    "display_name": "Corn (Yellow)",
    "category": "Corn",
    "specification": "Cob, Sweet Corn",
    "unit": "kg"
  },
  "a276f3a4-90e3-49f9-99e4-e58c29674ed8": {
    "display_name": "Corn Grits (White, Food Grade)",
    "category": "Corn",
    "specification": "White, Food Grade",
    "unit": "kg"
  },
  "d06ef84f-4ea1-4594-9c94-2c2cf6714f2b": {
    "display_name": "Corn Grits (Yellow, Food Grade)",
    "category": "Corn",
    "specification": "Yellow, Food Grade",
    "unit": "kg"
  },
  "b123be5c-f444-4edf-a90d-a252b17cbf85": {
    "display_name": "Corn Cracked (Yellow, Feed Grade)",
    "category": "Corn",
    "specification": "Yellow, Feed Grade",
    "unit": "kg"
  },
  "db145dd7-4e49-4c59-b126-f1278b8c657a": {
    "display_name": "Corn Grits (Feed Grade)",
    "category": "Corn",
    "specification": "Feed Grade",
    "unit": "kg"
  },
  
  // Fish
  "f777f967-b403-4fb1-82a1-049529b96969": {
    "display_name": "Bangus",
    "category": "Fish",
    "specification": "Large",
    "unit": "kg"
  },
  "5d4c72e5-3be3-4f49-891c-d0aef1475a31": {
    "display_name": "Bangus",
    "category": "Fish",
    "specification": "Medium(3-4pcs/kg)",
    "unit": "kg"
  },
  "39992652-ed65-4449-9e79-b148d7854096": {
    "display_name": "Tilapia",
    "category": "Fish",
    "specification": "Medium (5-6pcs/kg)",
    "unit": "kg"
  },
  "8465c868-2b9d-457e-8b21-01a8a736fc4c": {
    "display_name": "Galunggong (Local)",
    "category": "Fish",
    "specification": "Male, Medium (12-14pcs/kg)",
    "unit": "kg"
  },
  "ded96750-760a-4d84-a781-0ad531aa4aec": {
    "display_name": "Galunggong (Imported)",
    "category": "Fish",
    "specification": "Male, Medium (12-14pcs/kg)",
    "unit": "kg"
  },
  "9aeb94dc-d43d-4c49-830c-0cb49b129658": {
    "display_name": "Alumahan",
    "category": "Fish",
    "specification": "Medium (4-5pcs/kg)",
    "unit": "kg"
  },
  "21461ff7-4375-42f8-91ef-a535ff528aa1": {
    "display_name": "Bonito",
    "category": "Fish",
    "specification": "-",
    "unit": "kg"
  },
  "6fa07688-4162-417e-8f5f-5d7d090005f5": {
    "display_name": "Salmon Head",
    "category": "Fish",
    "specification": "-",
    "unit": "kg"
  },
  "94a27951-fa89-4738-af6f-3ba5d6d5167a": {
    "display_name": "Sardines (Tamban)",
    "category": "Fish",
    "specification": "-",
    "unit": "kg"
  },
  "ce905a07-ba3e-40a2-8a57-a07e3bebbc5e": {
    "display_name": "Squid (Pusit Bisaya)",
    "category": "Fish",
    "specification": "Medium",
    "unit": "kg"
  },
  "c9300905-be4e-41c8-948f-c01be993e9cd": {
    "display_name": "Yellow-Fin Tuna (Tambakol)",
    "category": "Fish",
    "specification": "-",
    "unit": "kg"
  },
  
  // Livestock & Poultry Products
  "a4fdf7eb-a3ce-468b-b214-b9eca8675ea8": {
    "display_name": "Beef Rump",
    "category": "Livestock & Poultry Products",
    "specification": "Lean Meat/Tapadera",
    "unit": "kg"
  },
  "5ea79e0f-0743-42bc-9f50-676825f45dd1": {
    "display_name": "Beef Brisket",
    "category": "Livestock & Poultry Products",
    "specification": "Meat with Bones",
    "unit": "kg"
  },
  "f2e43290-9911-4b0a-96bd-b9efbc12c640": {
    "display_name": "Pork Ham",
    "category": "Livestock & Poultry Products",
    "specification": "Kasim",
    "unit": "kg"
  },
  "2737740b-f64b-4683-ae85-8e44706c5e60": {
    "display_name": "Pork Belly",
    "category": "Livestock & Poultry Products",
    "specification": "Liempo",
    "unit": "kg"
  },
  "1cf8a8ce-8697-4b1b-ac51-23c0b26e0633": {
    "display_name": "Frozen Kasim",
    "category": "Livestock & Poultry Products",
    "specification": "-",
    "unit": "kg"
  },
  "dd395989-032f-4a60-86bf-e13af052ff1e": {
    "display_name": "Frozen Liempo",
    "category": "Livestock & Poultry Products",
    "specification": "-",
    "unit": "kg"
  },
  "8d369885-a625-4ddb-bddf-0ac6ec4ad8b3": {
    "display_name": "Whole Chicken",
    "category": "Livestock & Poultry Products",
    "specification": "Fully Dressed",
    "unit": "kg"
  },
  "84b1b16d-f904-458c-8e47-969cc00dcb09": {
    "display_name": "Chicken Egg (White, Pewee)",
    "category": "Livestock & Poultry Products",
    "specification": "41-45 grams/pc",
    "unit": "pc"
  },
  "5e1c133c-af56-4d94-b7e0-d2c245acd798": {
    "display_name": "Chicken Egg (White, Extra Small)",
    "category": "Livestock & Poultry Products",
    "specification": "46-50 grams/pc",
    "unit": "pc"
  },
  "9acac109-647f-4c64-b487-08095e59b8cc": {
    "display_name": "Chicken Egg (White, Small)",
    "category": "Livestock & Poultry Products",
    "specification": "51-55 grams/pc",
    "unit": "pc"
  },
  "b271a7dc-f79a-4e88-96b4-a2983f42ae43": {
    "display_name": "Chicken Egg (White, Medium)",
    "category": "Livestock & Poultry Products",
    "specification": "56-60 grams/pc",
    "unit": "pc"
  },
  "9ed31998-d241-43b0-8389-e801beb389ea": {
    "display_name": "Chicken Egg (White, Large)",
    "category": "Livestock & Poultry Products",
    "specification": "61-65 grams/pc",
    "unit": "pc"
  },
  "b6b27893-ca4b-455d-bf72-7401b52a1aaa": {
    "display_name": "Chicken Egg (White, Extra Large)",
    "category": "Livestock & Poultry Products",
    "specification": "66-70 grams/pc",
    "unit": "pc"
  },
  "d85cd0fc-039a-4440-a1ec-85dc332792af": {
    "display_name": "Chicken Egg (White, Jumbo)",
    "category": "Livestock & Poultry Products",
    "specification": "71> grams/pc",
    "unit": "pc"
  },
  "857ffb58-5ead-45b7-b201-ebfa9fb00315": {
    "display_name": "Chicken Egg (Brown, Medium)",
    "category": "Livestock & Poultry Products",
    "specification": "Medium",
    "unit": "pc"
  },
  "f8f50593-04a7-4365-b7a1-7e536203711d": {
    "display_name": "Chicken Egg (Brown, Large)",
    "category": "Livestock & Poultry Products",
    "specification": "Large",
    "unit": "pc"
  },
  "cb642a2d-7ed1-4e62-8b42-dcfaba5fe8c0": {
    "display_name": "Chicken Egg (Brown, Extra Large)",
    "category": "Livestock & Poultry Products",
    "specification": "Extra Large",
    "unit": "pc"
  },
  
  // Lowland Vegetables
  "5363dcb6-2300-4e2d-b1ce-95bdd4dcd3a1": {
    "display_name": "Ampalaya",
    "category": "Lowland Vegetables",
    "specification": "4-5 pcs/kg",
    "unit": "kg"
  },
  "1aa800bd-7a79-47de-99a4-2b3529049724": {
    "display_name": "Sitao",
    "category": "Lowland Vegetables",
    "specification": "3-4 Small Bundles",
    "unit": "kg"
  },
  "8b3e1c99-0f58-43c3-ba28-a998156de3e2": {
    "display_name": "Pechay (Native)",
    "category": "Lowland Vegetables",
    "specification": "3-4 Small Bundles",
    "unit": "kg"
  },
  "435ee502-aabf-488e-954a-c1d623eb3554": {
    "display_name": "Squash",
    "category": "Lowland Vegetables",
    "specification": "Suprema Variety",
    "unit": "kg"
  },
  "36f05146-cccf-4369-8b18-cd91797f01df": {
    "display_name": "Eggplant",
    "category": "Lowland Vegetables",
    "specification": "3-4 Small Bundles",
    "unit": "kg"
  },
  "eff25c06-c139-4e67-9dc4-b0927e55fc4e": {
    "display_name": "Tomato",
    "category": "Lowland Vegetables",
    "specification": "15-18 pcs/kg",
    "unit": "kg"
  },
  
  // Highland Vegetables
  "631aaa87-f59a-4c61-b070-f5fade4a526a": {
    "display_name": "Bell Pepper (Green)",
    "category": "Highland Vegetables",
    "specification": "Medium (151-250gm/pc)",
    "unit": "kg"
  },
  "b6891635-2f39-4177-aaba-900ecf8c215b": {
    "display_name": "Bell Pepper (Red)",
    "category": "Highland Vegetables",
    "specification": "Medium (151-250gm/pc)",
    "unit": "kg"
  },
  "fa9b8abe-7943-4dd7-b70d-4ff8ddd5039d": {
    "display_name": "Broccoli",
    "category": "Highland Vegetables",
    "specification": "Medium (8-10 diameter/bunch hd)",
    "unit": "kg"
  },
  "ae02b1f4-a7eb-4332-9d4d-bff179932f3c": {
    "display_name": "Cabbage (Rare Ball)",
    "category": "Highland Vegetables",
    "specification": "510 gm - 1kg/head",
    "unit": "kg"
  },
  "aae5b77b-cc46-4cd3-b53a-cc078d9392d2": {
    "display_name": "Cabbage (Scorpio)",
    "category": "Highland Vegetables",
    "specification": "750 gm - 1kg/head",
    "unit": "kg"
  },
  "f3b5e136-02b8-43fa-b477-6d764792f58a": {
    "display_name": "Cabbage (Wonder Ball)",
    "category": "Highland Vegetables",
    "specification": "510 gm - 1kg/head",
    "unit": "kg"
  },
  "f48b5992-6756-4eef-8236-3c567d4821a6": {
    "display_name": "Carrots",
    "category": "Highland Vegetables",
    "specification": "8-10 pcs/kg",
    "unit": "kg"
  },
  "6c6cb439-9496-407e-9d36-f31354482837": {
    "display_name": "Habichuelas (Baguio Beans)",
    "category": "Highland Vegetables",
    "specification": "-",
    "unit": "kg"
  },
  "275ff056-870b-4347-bd7e-c6c63553c012": {
    "display_name": "White Potato",
    "category": "Highland Vegetables",
    "specification": "10-12 pcs/kg",
    "unit": "kg"
  },
  "e60994d2-20df-423f-adab-923ecc8f514d": {
    "display_name": "Pechay (Baguio)",
    "category": "Highland Vegetables",
    "specification": "-",
    "unit": "kg"
  },
  "54c023c8-b9dd-4a40-854e-ddf4dd2a07d1": {
    "display_name": "Chayote",
    "category": "Highland Vegetables",
    "specification": "Medium (301-400 g)",
    "unit": "kg"
  },
  "aa994e4a-38da-473c-b3e0-f75fd73140d9": {
    "display_name": "Cauliflower",
    "category": "Highland Vegetables",
    "specification": "Medium (8-10 diameter/bunch hd)",
    "unit": "kg"
  },
  "98020132-de96-4bb1-834f-21cc83489fe4": {
    "display_name": "Celery",
    "category": "Highland Vegetables",
    "specification": "Medium (501-800 g)",
    "unit": "kg"
  },
  "589debb5-9b6c-4d35-ae47-cc1d9edbcecb": {
    "display_name": "Lettuce (Green Ice)",
    "category": "Highland Vegetables",
    "specification": "-",
    "unit": "kg"
  },
  "f0c8e113-7e95-4e27-a722-f1048ac7d1c7": {
    "display_name": "Lettuce (Iceberg)",
    "category": "Highland Vegetables",
    "specification": "Medium (301-450 cm diameter/bunch hd)",
    "unit": "kg"
  },
  "145de2b2-ef52-4662-aa8f-5d6c2694d456": {
    "display_name": "Lettuce (Romaine)",
    "category": "Highland Vegetables",
    "specification": "-",
    "unit": "kg"
  },
  
  // Spices
  "61dbc9c6-5e7a-448a-a7fb-924d379b12ca": {
    "display_name": "Red Onion",
    "category": "Spices",
    "specification": "13-15 pcs/kg",
    "unit": "kg"
  },
  "7eafe09d-8b78-4931-932f-3de423b166cf": {
    "display_name": "Red Onion (Imported)",
    "category": "Spices",
    "specification": "-",
    "unit": "kg"
  },
  "4a9e25f3-8d44-4856-97aa-2546e9909036": {
    "display_name": "White Onion",
    "category": "Spices",
    "specification": "-",
    "unit": "kg"
  },
  "f437ca5b-b4a8-4c14-b416-0c077076b304": {
    "display_name": "White Onion (Imported)",
    "category": "Spices",
    "specification": "-",
    "unit": "kg"
  },
  "ac8e04e0-d3e0-4a4e-8ea4-4936339b8940": {
    "display_name": "Garlic (Imported)",
    "category": "Spices",
    "specification": "-",
    "unit": "kg"
  },
  "128f64ec-8a04-4d39-9d7c-ad19db3abf4f": {
    "display_name": "Garlic (Native)",
    "category": "Spices",
    "specification": "-",
    "unit": "kg"
  },
  "d30409d2-8dd5-4a83-98cf-f81e39040390": {
    "display_name": "Ginger",
    "category": "Spices",
    "specification": "Fairly well-matured, Medium (150-300 gm)",
    "unit": "kg"
  },
  "ae7cb1dd-c945-498f-83df-d70d48653c4d": {
    "display_name": "Chili (Red)",
    "category": "Spices",
    "specification": "-",
    "unit": "kg"
  },
  
  // Fruits
  "fff4585f-7312-47e4-b35d-0d33eac3f25a": {
    "display_name": "Calamansi",
    "category": "Fruits",
    "specification": "-",
    "unit": "kg"
  },
  "35740bb5-8198-42e8-a04e-2c7c47ad87c1": {
    "display_name": "Banana (Lakatan)",
    "category": "Fruits",
    "specification": "8-10 pcs/kg",
    "unit": "kg"
  },
  "e9aea691-b63a-4fe2-b854-2e85579c747e": {
    "display_name": "Banana (Latundan)",
    "category": "Fruits",
    "specification": "10-12 pcs/kg",
    "unit": "kg"
  },
  "05082cc1-abe7-49f2-9402-e9ba4ce79c44": {
    "display_name": "Banana (Saba)",
    "category": "Fruits",
    "specification": "-",
    "unit": "kg"
  },
  "82ff2170-878d-4173-8708-e560f00471eb": {
    "display_name": "Papaya",
    "category": "Fruits",
    "specification": "Solo, Ripe, 2-4 pcs/kg",
    "unit": "kg"
  },
  "caa57ba0-efb7-4d79-a854-2fa1d2505a82": {
    "display_name": "Mango (Carabao)",
    "category": "Fruits",
    "specification": "Ripe, 3-4 pcs/kg",
    "unit": "kg"
  },
  "dd281fdb-af5e-4f96-a665-6013d910eac7": {
    "display_name": "Avocado",
    "category": "Fruits",
    "specification": "-",
    "unit": "kg"
  },
  "c0ca8a36-2cf0-4a1a-b321-a2467e90bcdb": {
    "display_name": "Melon",
    "category": "Fruits",
    "specification": "-",
    "unit": "kg"
  },
  "dc78979f-c6db-46e4-85c0-3db7a5cfba68": {
    "display_name": "Pomelo",
    "category": "Fruits",
    "specification": "-",
    "unit": "kg"
  },
  "90099d3c-9f93-4434-b2bf-c9cbecf49899": {
    "display_name": "Watermelon",
    "category": "Fruits",
    "specification": "-",
    "unit": "kg"
  },
  
  // Other Basic Commodities
  "11445870-6301-4bf5-9a25-63ae1efa7400": {
    "display_name": "Sugar (Refined)",
    "category": "Other Basic Commodities",
    "specification": "-",
    "unit": "kg"
  },
  "3be1e1bd-c54a-4f2f-b503-74c86c8c04fc": {
    "display_name": "Sugar (Washed)",
    "category": "Other Basic Commodities",
    "specification": "-",
    "unit": "kg"
  },
  "ef817cb0-4984-4eda-bb80-ad3a8e31e673": {
    "display_name": "Sugar (Brown)",
    "category": "Other Basic Commodities",
    "specification": "-",
    "unit": "kg"
  },
  "e85028a4-d668-4079-9567-76f81a32a5c9": {
    "display_name": "Cooking Oil (Palm)",
    "category": "Other Basic Commodities",
    "specification": "350 ml/bottle",
    "unit": "ml"
  },
  "48fab619-de31-4645-b0d9-c1608865b628": {
    "display_name": "Cooking Oil (Palm)",
    "category": "Other Basic Commodities",
    "specification": "1 liter/bottle",
    "unit": "L"
  },
  "a13e2976-7f21-496a-93c4-35c689f78174": {
    "display_name": "Cooking Oil (Coconut)",
    "category": "Other Basic Commodities",
    "specification": "350 ml/bottle",
    "unit": "ml"
  },
  "be1b16b3-fbb1-402f-97e4-2cb82f3c32a5": {
    "display_name": "Cooking Oil (Coconut)",
    "category": "Other Basic Commodities",
    "specification": "1 liter/bottle",
    "unit": "L"
  },
};

// Helper function to group commodities by category
Map<String, List<String>> getCommoditiesByCategory() {
  Map<String, List<String>> result = {};
  
  // Initialize with empty lists for each category
  for (String category in COMMODITY_CATEGORIES) {
    result[category] = [];
  }
  
  // Group commodities by their categories
  COMMODITY_ID_TO_DISPLAY.forEach((id, data) {
    final category = data['category'] ?? "";
    if (result.containsKey(category)) {
      result[category]!.add(id);
    }
  });
  
  return result;
}