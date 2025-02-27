// Relays don't handle any actual communication. Global NTNet datum does that, relays only tell the datum if it should or shouldn't work.
/obj/machinery/ntnet_relay
	name = "NTNet Quantum Relay"
	desc = "A very complex router and transmitter capable of connecting electronic devices together. Looks fragile."
	use_power = ACTIVE_POWER_USE
	active_power_usage = 10000 //10kW, apropriate for machine that keeps massive cross-Zlevel wireless network operational. Used to be 20 but that actually drained the smes one round
	idle_power_usage = 100
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "bus"
	density = TRUE
	circuit = /obj/item/circuitboard/machine/ntnet_relay



	var/datum/ntnet/NTNet = null // This is mostly for backwards reference and to allow varedit modifications from ingame.
	var/enabled = 1				// Set to 0 if the relay was turned off
	var/dos_failure = 0			// Set to 1 if the relay failed due to (D)DoS attack
	var/list/dos_sources = list()	// Backwards reference for qdel() stuff
	var/uid
	var/static/gl_uid = 1

	// Denial of Service attack variables
	var/dos_overload = 0		// Amount of DoS "packets" in this relay's buffer
	var/dos_capacity = 500		// Amount of DoS "packets" in buffer required to crash the relay
	var/dos_dissipate = 0.5		// Amount of DoS "packets" dissipated over time.


// TODO: Implement more logic here. For now it's only a placeholder.
/obj/machinery/ntnet_relay/is_operational()
	if(stat & (BROKEN | NOPOWER | EMPED))
		return FALSE
	if(dos_failure)
		return FALSE
	if(!enabled)
		return FALSE
	return TRUE

/obj/machinery/ntnet_relay/update_icon()
	if(is_operational())
		icon_state = "bus"
	else
		icon_state = "bus_off"

/obj/machinery/ntnet_relay/process(delta_time)
	if(is_operational())
		use_power = ACTIVE_POWER_USE
	else
		use_power = IDLE_POWER_USE

	update_icon()

	if(dos_overload > 0)
		dos_overload = max(0, dos_overload - dos_dissipate * delta_time)

	// If DoS traffic exceeded capacity, crash.
	if((dos_overload > dos_capacity) && !dos_failure)
		dos_failure = 1
		ui_update()
		update_icon()
		SSnetworks.add_log("Quantum relay switched from normal operation mode to overload recovery mode.")
	// If the DoS buffer reaches 0 again, restart.
	if((dos_overload == 0) && dos_failure)
		dos_failure = 0
		ui_update()
		update_icon()
		SSnetworks.add_log("Quantum relay switched from overload recovery mode to normal operation mode.")
	..()


/obj/machinery/ntnet_relay/ui_state(mob/user)
	return GLOB.default_state

/obj/machinery/ntnet_relay/ui_interact(mob/user, datum/tgui/ui)

	ui = SStgui.try_update_ui(user, src, ui)

	if(!ui)
		ui = new(user, src, "NtnetRelay")
		ui.open()


/obj/machinery/ntnet_relay/ui_data(mob/user)
	var/list/data = list()
	data["enabled"] = enabled
	data["dos_capacity"] = dos_capacity
	data["dos_overload"] = dos_overload
	data["dos_crashed"] = dos_failure
	return data


/obj/machinery/ntnet_relay/ui_act(action, params)
	if(..())
		return
	switch(action)
		if("restart")
			dos_overload = 0
			dos_failure = 0
			update_icon()
			SSnetworks.add_log("Quantum relay manually restarted from overload recovery mode to normal operation mode.")
			return TRUE
		if("toggle")
			enabled = !enabled
			SSnetworks.add_log("Quantum relay manually [enabled ? "enabled" : "disabled"].")
			update_icon()
			return TRUE

/obj/machinery/ntnet_relay/Initialize(mapload)
	uid = gl_uid++
	component_parts = list()

	if(SSnetworks.station_network)
		SSnetworks.relays.Add(src)
		NTNet = SSnetworks.station_network
		SSnetworks.add_log("New quantum relay activated. Current amount of linked relays: [SSnetworks.relays.len]")
	. = ..()

/obj/machinery/ntnet_relay/Destroy()
	if(SSnetworks.station_network)
		SSnetworks.relays.Remove(src)
		SSnetworks.add_log("Quantum relay connection severed. Current amount of linked relays: [SSnetworks.relays.len]")
		NTNet = null

	for(var/datum/computer_file/program/ntnet_dos/D in dos_sources)
		D.target = null
		D.error = "Connection to quantum relay severed"

	return ..()
