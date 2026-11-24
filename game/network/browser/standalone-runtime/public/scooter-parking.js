// Shared layout for visuals, spawn and authoritative scooter return.
export const scooterBay=Object.freeze({x:-20,z:3,visitX:-20,visitZ:5});
export const scooterSpots=Object.freeze([-22,-20,-18].map(x=>Object.freeze({x,z:3.5,yaw:0})));
export function inScooterBay(x,z){return Number.isFinite(x)&&Number.isFinite(z)&&((x>=-25&&x<=-15&&z>=.5&&z<=5.5)||(x>=-23&&x<=-17&&z>=5&&z<=9));}
export function canReturnScooter(car,seat){return car?.kind==='scooter'&&seat==='driver'&&Number.isFinite(car.speed)&&Math.abs(car.speed)<=.01&&inScooterBay(car.x,car.z);}
export function scooterReturnSpot(car,cars){return scooterSpots.find(s=>!cars.some(c=>c!==car&&Math.hypot(c.x-s.x,c.z-s.z)<1.5))??null;}
