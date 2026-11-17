import {mkdir,access,copyFile,writeFile} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec=promisify(execFile);
import {fileURLToPath} from 'node:url';
import {dirname,join,resolve} from 'node:path';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const publicDir=join(root,'public');
await mkdir(publicDir,{recursive:true});
const exists=async p=>{try{await access(p);return true}catch{return false}};
const logo=join(publicDir,'primespaces-logo.png');
if(!await exists(logo)){
 const repositoryLogo=resolve(root,'../../assets/logo.png');
 if(await exists(repositoryLogo))await copyFile(repositoryLogo,logo);
 else await download('https://raw.githubusercontent.com/cway917/PrimeSpaces/main/assets/logo.png',logo);
}
const photos={gym:'photo-1546519638-68e109498ffc',hall:'photo-1519167758481-83f550bb49b3',meeting:'photo-1497366754035-f200968a6e72',auditorium:'photo-1503428593586-e225b39bddfe',field:'photo-1526232761682-d26e03ac148e',classroom:'photo-1503676260728-1c00da094a0b'};
await Promise.all(Object.entries(photos).map(async([name,id])=>{const target=join(publicDir,name+'.jpg');if(!await exists(target))await download('https://images.unsplash.com/'+id+'?w=1100&q=85&fit=crop',target)}));
async function download(url,path){try{const r=await fetch(url,{signal:AbortSignal.timeout(12000)});if(!r.ok)throw new Error('Asset download failed: '+r.status);await writeFile(path,new Uint8Array(await r.arrayBuffer()))}catch{await exec('curl',['--fail','--location','--silent','--show-error','--max-time','30',url,'--output',path])}}
