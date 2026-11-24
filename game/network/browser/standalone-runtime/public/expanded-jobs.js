import {workDefinitions} from './economy.js';
// Authoritative world-space work spots. Props sit just beyond these walkable spots.
const task=(name,id,label,dx,dz,kind,durationMs=2000)=>{const b=workDefinitions[name];return Object.freeze({id,label,x:b.x+dx,z:b.z+dz,radius:1.8,interiorBusiness:b.business,durationMs,kind});};
const job=(name,title,start,steps)=>Object.freeze({title,station:task(name,'work-start-'+name,start[0],start[1],start[2],start[3],0),tasks:Object.freeze(steps.map(s=>task(name,...s)))});
export const expandedJobs=Object.freeze({
 vet:job('vet','Pet care shift',['Collect the pet-care kit',-3,4,'care-kit'],[
  ['brush-kit','Pick up the soft brush',-3,2,'brush'],['comfort-pet','Gently brush the waiting puppy',3,2,'dog'],['fresh-water','Fill the puppy water bowl',5,4.5,'bowl']]),
 salon:job('salon','Salon styling shift',['Pick up the salon apron',-2,4.8,'apron'],[
  ['choose-brush','Collect a styling brush',-3,1.8,'brush'],['brush-client','Brush the customer hair',-3,-3.4,'customer'],['choose-ribbon','Choose a colorful ribbon',3,1.8,'ribbon'],['finish-style','Show the customer their new style',-3,-3.4,'customer']]),
 cafe:job('cafe','Cafe order shift',['Collect the cafe order tray',0,3.5,'tray'],[
  ['collect-plate','Collect a clean plate',-2,-3.2,'plate'],['add-muffin','Put a muffin on the plate',2,-3.2,'muffin'],['serve-order','Serve the order at the window table',2.7,3.6,'tray']]),
 store:job('store','Store stocking shift',['Pick up the stock checklist',0,2,'clipboard'],[
  ['collect-stock','Collect a stock box',3,0,'package'],['fill-shelf','Arrange the stock on the shelf',-3,0,'package'],['check-stock','Check the completed stock list',0,-1.4,'clipboard']]),
 library:job('library','Library book shift',['Collect the book return basket',-2.8,4.8,'book-basket'],[
  ['collect-book','Collect the returned storybook',-2.8,1.4,'book'],['shelve-red','Shelve the red storybook',-3.8,-4.5,'red-book'],['shelve-blue','Shelve the blue storybook',3.8,-4.5,'blue-book'],['help-reader','Bring a book to the reading corner',3,3,'book']]),
 bank:job('bank','Bank coin sorting shift',['Collect the coin sorting tray',-3,4,'coins'],[
  ['sort-copper','Sort the copper coins',-3,1.6,'copper-coins'],['sort-silver','Sort the silver coins',-3,-2,'silver-coins'],['count-stars','Count the gold star coins',3,-2,'gold-coins'],['pack-coins','Pack the sorted coins for the teller',3,3,'coin-pouch']]),
 park:job('park','Park cleanup shift',['Collect the cleanup basket',-3,4,'basket'],[
  ['collect-paper','Pick up the paper near the bench',-4,2,'paper'],['collect-cup','Pick up the empty cup',4,2,'cup'],['recycle-litter','Sort the litter into the recycling bin',4,-3,'bin']]),
 singing:job('singing','Stage melody shift',['Pick up the song card',0,3,'song-card'],[
  ['note-red','Play the red note: Do',-2,1,'note-red',1500],['note-yellow','Play the yellow note: Mi',0,1,'note-yellow',1500],['note-blue','Play the blue note: Sol',2,1,'note-blue',1500],['take-bow','Take a bow at the microphone',0,-.5,'microphone',1500]])
});
export const expandedJob=name=>Object.hasOwn(expandedJobs,name)?expandedJobs[name]:null;
