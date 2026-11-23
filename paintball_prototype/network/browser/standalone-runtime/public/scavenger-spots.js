import {businessDefinitions} from './business-interiors.js';
// Curated outdoor ground locations, checked against town-layout, business shells,
// scenery, maximum home/yard extents and a conservative walkability grid.
// No markers are created here. Every new run chooses a subset server-side.
// Coordinate checks are source-derived; browser walk-through remains separate QA.
const outdoorSpots=Object.freeze([
 [
  "park-west",
  7,
  -25,
  "Beside the west edge of the park"
 ],
 [
  "park-north",
  14,
  -31,
  "Along the north edge of the park"
 ],
 [
  "park-south",
  22,
  -17,
  "South of the park benches"
 ],
 [
  "park-northeast",
  27,
  -30,
  "At the northeast corner of the park"
 ],
 [
  "library-west",
  -25,
  -24,
  "Beside the west wall of the library"
 ],
 [
  "library-east",
  -8,
  -27,
  "East of the library"
 ],
 [
  "library-north",
  -23,
  -31,
  "Near the north corner of the library"
 ],
 [
  "library-south",
  -9,
  -17,
  "Near the library approach"
 ],
 [
  "bank-west",
  -62,
  -55,
  "By the west side of Willow Bank"
 ],
 [
  "bank-east",
  -44,
  -49,
  "East of Willow Bank"
 ],
 [
  "vet-northwest",
  -26,
  -55,
  "Near the northwest side of Pet Vet"
 ],
 [
  "vet-east",
  -10,
  -49,
  "Beside Pet Vet"
 ],
 [
  "salon-northwest",
  10,
  -56,
  "Northwest of the beauty salon"
 ],
 [
  "salon-east",
  26,
  -50,
  "East of the beauty salon"
 ],
 [
  "stage-west",
  44,
  -49,
  "West of Starlight Stage"
 ],
 [
  "stage-front-east",
  61,
  -44,
  "By the east side of the stage approach"
 ],
 [
  "store-west",
  -25,
  25,
  "West of Town Store"
 ],
 [
  "store-east",
  -8,
  26,
  "Beside the east side of Town Store"
 ],
 [
  "store-southwest",
  -23,
  31,
  "Near the south corner of Town Store"
 ],
 [
  "cafe-east",
  24,
  25,
  "East of Sunny Cafe"
 ],
 [
  "cafe-southwest",
  8,
  29,
  "Near the southwest side of Sunny Cafe"
 ],
 [
  "cafe-southeast",
  25,
  31,
  "Near the southeast side of Sunny Cafe"
 ],
 [
  "garden-east",
  27,
  47,
  "Along the east edge of the garden"
 ],
 [
  "garden-southeast",
  27,
  55,
  "Near the southeast corner of the garden"
 ],
 [
  "garden-southwest",
  13,
  55,
  "Southwest of the garden"
 ],
 [
  "nursery-west",
  -30,
  47,
  "Outside the west edge of the nursery"
 ],
 [
  "nursery-southwest",
  -30,
  55,
  "Near the southwest corner of the nursery"
 ],
 [
  "playground-west",
  40,
  54,
  "Along the west edge of the playground"
 ],
 [
  "playground-southeast",
  58,
  55,
  "Near the southeast corner of the playground"
 ],
 [
  "skate-southwest",
  -59,
  55,
  "At the southwest edge of Skate Corner"
 ],
 [
  "skate-east",
  -40,
  54,
  "Along the east edge of Skate Corner"
 ],
 [
  "pond-south",
  -13,
  57,
  "Beside the south shore of the pond"
 ]
].map(([id,x,z,hint])=>Object.freeze({id,x,z,hint,interiorBusiness:null})));
// World-relative coordinates in single public-business instances. Never private homes.
const indoorRows=[
 ['bank-west-inside','bank',-7,-2,'Inside Willow Bank, along the west wall'],
 ['bank-east-inside','bank',7,-3,'Inside Willow Bank, near the east side'],
 ['vet-west-inside','vet',-7,-2,'Inside Pet Vet, along the west wall'],
 ['vet-east-inside','vet',7,-3,'Inside Pet Vet, east of the examination table'],
 ['salon-west-inside','salon',-7,-1.5,'Inside Beauty Salon, along the west wall'],
 ['salon-east-inside','salon',7,-1.5,'Inside Beauty Salon, along the east wall'],
 ['cafe-west-inside','cafe',-7,-3,'Inside Sunny Cafe, near the west wall'],
 ['cafe-east-inside','cafe',7,-3,'Inside Sunny Cafe, near the east wall'],
 ['store-west-inside','store',-7.8,-3,'Inside Town Store, in the west side aisle'],
 ['store-east-inside','store',7.8,-3,'Inside Town Store, in the east side aisle'],
 ['library-west-inside','library',-6,-4,'Inside the Library, near the northwest bookshelves'],
 ['library-east-inside','library',6,-4,'Inside the Library, near the northeast bookshelves']
];
export const scavengerIndoorSpots=Object.freeze(indoorRows.map(([id,interiorBusiness,dx,dz,hint])=>{const b=businessDefinitions[interiorBusiness];return Object.freeze({id,x:b.x+dx,z:b.z+dz,hint,interiorBusiness});}));
export const scavengerSpots=Object.freeze([...outdoorSpots,...scavengerIndoorSpots]);
export const scavengerSpot=id=>typeof id==='string'?scavengerSpots.find(s=>s.id===id):undefined;
