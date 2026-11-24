import {atJobTask} from './job-tasks.js';
const site=(id,label,x,z,interiorBusiness=null)=>Object.freeze({id,label,x,z,interiorBusiness,radius:1.7});
export const employerSites=Object.freeze({
 bank:site('bank','Bank teller',-54,-47.8,'bank'),vet:site('vet','Veterinarian',-18,-47.8,'vet'),library:site('library','Librarian',-16,-22.8,'library'),
 store:site('store','Shopkeeper',-16,22.2,'store'),cafe:site('cafe','Cafe host',20.5,20.3,'cafe'),salon:site('salon','Salon receptionist',18,-52.5,'salon'),
 nursery:site('nursery','Nursery gardener',-23,46.6),park:site('park','Mayor',24,-26),singing:site('singing','Stage host',49,-47.5)
});
export const jobEmployer=Object.freeze({delivery:'store',store:'store',bank:'bank',vet:'vet',library:'library',cafe:'cafe',salon:'salon',nursery:'nursery',park:'park',singing:'singing'});
export const employerFor=name=>typeof name==='string'&&Object.hasOwn(jobEmployer,name)?employerSites[jobEmployer[name]]:null;
export const atEmployer=(position,name)=>atJobTask(position,employerFor(name));

