This project extends the actionscript LocalConnection class to add the ability to make to make asynchronous function calls between two connected clients.  Additionally, messages sent between two connected clients are not subject to the 40KB limit imposed by the standard LocalConnection class:

Example:

package
{
        import com.dubitplatform.localConnection.LocalConnectionService;
	
	import flash.events.StatusEvent;
	
	import mx.events.PropertyChangeEvent;
	import mx.rpc.AsyncToken;

	public class LocalConnectionTest
	{
		private var localConnectionSerivce:LocalConnectionService;
		
		public function LocalConnectionTest()
		{
			/* Instanciate new LocalConnectionService and provide the 'client' object which contains functions which 
  		       are available to be called by a remote client */
			localConnectionSerivce = new LocalConnectionService(this);
			
			/* Listen for status events from the service - Specifically the "Connected" event.  Possible status events 
			   dispatched are:
				"idle" - Nothing is happening
				"connecting" - The service is trying to establish a connection
				"waitingForRemoteClient" - The service is waiting for a remote client to connect
				"connected" - A remote client has connected
				"timedOut" - The remote client has timed out
				"closing" - The service is disconnecting
			*/
			localConnectionSerivce.addEventListener(StatusEvent.STATUS, function(e:StatusEvent) : void
			{
				if(e.code == LocalConnectionService.CONNECTED) callRemoteFunction();
			});
			
			// Start the service
			localConnectionSerivce.connect("localConnectionTest");
		}
		
		private function callRemoteFunction() : void
		{
			/* When calling a function on the remoteClient an asyncToken is returned.  When the clients reponse is recieved
			   this token will be notified - Here we are calling the "timesByTwo" function on the remote client */
			var asyncToken:AsyncToken = localConnectionSerivce.remoteClient.timesByTwo(42);
			
			// Add listener which will be notified when a response has been recieved
			asyncToken.addEventListener(PropertyChangeEvent.PROPERTY_CHANGE, function(e:PropertyChangeEvent) : void
			{
				trace(e.newValue); // Traces out 84
			});
		}
		
		// This public function is available to a remote client
		public function timesByTwo(input:int) : int
		{
			return input * 2;
		}
	}
}