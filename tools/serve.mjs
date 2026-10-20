import {createServer} from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {resolve,sep,extname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../docs/',import.meta.url));
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.ico':'image/x-icon'};
const server=createServer(async(req,res)=>{try{const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);let path=resolve(root,'.'+pathname);if(path!==resolve(root)&&!path.startsWith(resolve(root)+sep)){res.writeHead(403).end();return}if((await stat(path)).isDirectory())path=resolve(path,'index.html');const bytes=await readFile(path);res.writeHead(200,{'Content-Type':mime[extname(path)]||'application/octet-stream','Cache-Control':'no-store'}).end(bytes)}catch{res.writeHead(404).end('Not found')}});
server.listen(8080,'127.0.0.1',()=>console.log('Preview: http://127.0.0.1:8080/ (Ctrl+C to stop)'));
