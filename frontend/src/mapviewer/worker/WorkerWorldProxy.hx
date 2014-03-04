package mapviewer.worker;
import js.html.ArrayBuffer;
import js.html.Uint8Array;
import js.html.XMLHttpRequest;
import mapviewer.world.World;

class WorkerWorldProxy {

	public var owner : World;
	private var proxies : Array<WorkerProxy>;
	private var numberLoaded : Int = 0;
	private var lastProcessor : Int = 0;
	private var toLoad : Array<Array<Int>>;
	
	public function new(owner : World) {
		this.owner = owner;
		toLoad = new Array();
		proxies = new Array();
		for (i in 0 ... 3) {
			proxies[i] = new WorkerProxy(this, function() {
				numberLoaded++;
			});
		}
	}
	
	public function tick() {
		if (toLoad.length == 0 || numberLoaded != proxies.length) return;
		var dl = toLoad.pop();
		var x : Int = dl[0];
		var z : Int = dl[1];
		
		var req = new XMLHttpRequest();
		req.open("POST", 'http://${Main.connection.address}/chunk', true);
		req.responseType = "arraybuffer";
		req.onreadystatechange = function(e) {
			if (req.readyState == 4 && req.status == 200) {
				processChunk(req.response, x, z);
			}
		};
		req.send(World.chunkKey(x, z));
	}
	
	public function requestChunk(x : Int, z : Int) {
		toLoad.push([x, z]);
	}
	
	private function processChunk(buffer : ArrayBuffer, x : Int, z : Int) {
		var data = new Uint8Array(buffer);
		var message : Dynamic = { };
		message.type = "load";
		message.x = x;
		message.z = z;
		message.sendBack = false;
		for (proxy in proxies) {
			if (proxy.id == lastProcessor) message.sendBack = true;
			message.data = new Uint8Array(data);
			proxy.worker.postMessage(message, [message.data.buffer]);
			if (proxy.id == lastProcessor) message.sendBack = false;
		}
		lastProcessor = (lastProcessor + 1) % proxies.length;
	}
	
	public function removeChunk(x : Int, z : Int) {
		var message : Dynamic = { };
		message.type = "remove";
		message.x = x;
		message.z = z;
		for (proxy in proxies) {
			proxy.worker.postMessage(message);
		}
	}
}