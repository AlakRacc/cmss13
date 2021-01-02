

/obj/item/device/radio
	icon = 'icons/obj/items/radio.dmi'
	name = "station bounced radio"
	suffix = "\[3\]"
	icon_state = "walkietalkie"
	item_state = "walkietalkie"
	var/on = 1 // 0 for off
	var/last_transmission
	var/frequency = PUB_FREQ //common chat
	var/traitor_frequency = 0 //tune to frequency to unlock traitor supplies
	var/canhear_range = 3 // the range which mobs can hear this radio from
	var/wires = WIRE_SIGNAL|WIRE_RECEIVE|WIRE_TRANSMIT
	var/b_stat = 0
	var/broadcasting = 0
	var/listening = 1
	var/ignore_z = FALSE
	var/freerange = 0 // 0 - Sanitize frequencies, 1 - Full range
	var/list/channels = list() //see communications.dm for full list. First channes is a "default" for :h
	var/subspace_transmission = 0
	var/syndie = 0//Holder to see if it's a syndicate encrpyed radio
	var/maxf = 1499
//			"Example" = FREQ_LISTENING|FREQ_BROADCASTING
	flags_atom = FPRINT|CONDUCT
	flags_equip_slot = SLOT_WAIST
	throw_speed = SPEED_FAST
	throw_range = 9
	w_class = SIZE_SMALL

	matter = list("glass" = 25,"metal" = 75)

	var/const/WIRE_SIGNAL = 1 //sends a signal, like to set off a bomb or electrocute someone
	var/const/WIRE_RECEIVE = 2
	var/const/WIRE_TRANSMIT = 4
	var/const/TRANSMISSION_DELAY = 5 // only 2/second/radio
	var/const/FREQ_LISTENING = 1
		//FREQ_BROADCASTING = 2

	var/agent_unlocked = FALSE

/obj/item/device/radio
	var/datum/radio_frequency/radio_connection
	var/list/datum/radio_frequency/secure_radio_connections = new

	proc/set_frequency(new_frequency)
		SSradio.remove_object(src, frequency)
		frequency = new_frequency
		radio_connection = SSradio.add_object(src, frequency, RADIO_CHAT)

/obj/item/device/radio/Destroy()
	if(radio_connection)
		radio_connection.remove_listener(src)
		radio_connection = null
	if(secure_radio_connections)
		for(var/ch_name in secure_radio_connections)
			var/datum/radio_frequency/RF = secure_radio_connections[ch_name]
			if(!RF)
				continue
			RF.remove_listener(src)
			secure_radio_connections -= RF

	. = ..()


/obj/item/device/radio/proc/remove_all_freq()
	for(var/X in SSradio.frequencies)
		var/datum/radio_frequency/F = SSradio.frequencies[X]
		if(F)
			F.remove_listener(src)


/obj/item/device/radio/Initialize()
	. = ..()

	set_frequency(frequency)

	for (var/ch_name in channels)
		secure_radio_connections[ch_name] = SSradio.add_object(src, radiochannels[ch_name],  RADIO_CHAT)


/obj/item/device/radio/attack_self(mob/user as mob)
	user.set_interaction(src)
	interact(user)

/obj/item/device/radio/interact(mob/user as mob)
	if(!on)
		return

	var/dat = "<html><body><TT>"

	if(!istype(src, /obj/item/device/radio/headset)) //Headsets dont get a mic button
		dat += "Microphone: [broadcasting ? "<A href='byond://?src=\ref[src];talk=0'>Engaged</A>" : "<A href='byond://?src=\ref[src];talk=1'>Disengaged</A>"]<BR>"

	dat += {"
				Speaker: [listening ? "<A href='byond://?src=\ref[src];listen=0'>Engaged</A>" : "<A href='byond://?src=\ref[src];listen=1'>Disengaged</A>"]<BR>
				Frequency: 	[format_frequency(frequency)]<BR>"}
//				<A href='byond://?src=\ref[src];freq=-10'>-</A>
//				<A href='byond://?src=\ref[src];freq=-2'>-</A>
//
//				<A href='byond://?src=\ref[src];freq=2'>+</A>
//				<A href='byond://?src=\ref[src];freq=10'>+</A><BR>
//				"}

	dat += "<table>"
	for (var/ch_name in channels)
		dat+=text_sec_channel(ch_name, channels[ch_name])
	dat += "</table>"
	dat += "<br>"
	dat += "Special Frequency[agent_unlocked ? " (ACTIVATED)" : ""]:"
	dat += "<A href='byond://?src=\ref[src];special_frequency=1'>Call</A>"
	if(agent_unlocked)
		dat += "<A href='byond://?src=\ref[src];special_frequency_reset=1'>Reset</A>"
	dat += "<br><br>"
	dat += {"[text_wires()]</TT></body></html>"}
	show_browser(user, dat, name, "radio")
	return

/obj/item/device/radio/proc/text_wires()
	if (!b_stat)
		return ""
	return {"
			<hr>
			Green Wire: <A href='byond://?src=\ref[src];wires=4'>[(wires & 4) ? "Cut" : "Mend"] Wire</A><BR>
			Red Wire:   <A href='byond://?src=\ref[src];wires=2'>[(wires & 2) ? "Cut" : "Mend"] Wire</A><BR>
			Blue Wire:  <A href='byond://?src=\ref[src];wires=1'>[(wires & 1) ? "Cut" : "Mend"] Wire</A><BR>
			"}


/obj/item/device/radio/proc/text_sec_channel(var/chan_name, var/chan_stat)
	var/list = !!(chan_stat&FREQ_LISTENING)!=0
	var/channel_key
	for(var/key in department_radio_keys)
		if(department_radio_keys[key] == chan_name)
			channel_key = key
			break
	return {"
			<tr><td><B>[chan_name]</B>	[channel_key]</td>
			<td><A href='byond://?src=\ref[src];ch_name=[chan_name];listen=[!list]'>[list ? "Engaged" : "Disengaged"]</A></td></tr>
			"}

/obj/item/device/radio/Topic(href, href_list)
	. = ..()
	if(.)
		return
	if (usr.stat || !on)
		return

	if (!(isRemoteControlling(usr) || (usr.contents.Find(src) || ( in_range(src, usr) && istype(loc, /turf) ))))
		close_browser(usr, "radio")
		return
	usr.set_interaction(src)
	if (href_list["track"])
		var/mob/target = locate(href_list["track"])
		var/mob/living/silicon/ai/A = locate(href_list["track2"])
		if(A && target)
			A.ai_actual_track(target)
		return

	else if (href_list["freq"])
		var/new_frequency = (frequency + text2num(href_list["freq"]))
		if (!freerange || (frequency < 1200 || frequency > 1600))
			new_frequency = sanitize_frequency(new_frequency)
		set_frequency(new_frequency)

	else if (href_list["talk"])
		broadcasting = text2num(href_list["talk"])
	else if (href_list["listen"])
		var/chan_name = href_list["ch_name"]
		if (!chan_name)
			listening = text2num(href_list["listen"])
		else
			if (channels[chan_name] & FREQ_LISTENING)
				channels[chan_name] &= ~FREQ_LISTENING
			else
				channels[chan_name] |= FREQ_LISTENING
	else if (href_list["wires"])
		var/t1 = text2num(href_list["wires"])
		if (!( istype(usr.get_active_hand(), /obj/item/tool/wirecutters) ))
			return
		if (wires & t1)
			wires &= ~t1
		else
			wires |= t1

	if (href_list["special_frequency"])
		if(!ishuman(usr))
			return

		var/mob/living/carbon/human/H = usr
		if(!agent_unlocked)
			var/special_freq = input(usr, "What frequency do you want to tune it to?") as num|null
			if(!special_freq)
				return

			if(H.agent_holder && H.agent_holder.frequency_code != special_freq || !H.agent_holder)
				to_chat(usr, SPAN_NOTICE("The frequency tuned to doesn't respond."))
				return

			agent_unlocked = TRUE

		//open up the vendor shit
		if(!H.agent_holder || !H.agent_holder.tools)
			return

		H.agent_holder.tools.attack_self(usr)
		attack_self(usr)
		return

	if (href_list["special_frequency_reset"])
		if(!agent_unlocked)
			return

		agent_unlocked = FALSE
		attack_self(usr)
		return

	if (!( master ))
		if (istype(loc, /mob))
			interact(loc)
		else
			updateDialog()
	else
		if (istype(master.loc, /mob))
			interact(master.loc)
		else
			updateDialog()
	add_fingerprint(usr)

// Interprets the message mode when talking into a radio, possibly returning a connection datum
/obj/item/device/radio/proc/handle_message_mode(mob/living/M as mob, message, message_mode)
	// If a channel isn't specified, send to common.
	if(!message_mode || message_mode == "headset")
		return radio_connection

	// Otherwise, if a channel is specified, look for it.
	if(channels && channels.len)
		if (message_mode == "department" ) // Department radio shortcut
			message_mode = channels[1]

		if (channels[message_mode]) // only broadcast if the channel is set on
			return secure_radio_connections[message_mode]

	// If we were to send to a channel we don't have, drop it.
	return null

/obj/item/device/radio/talk_into(mob/living/M as mob, message, channel, var/verb = "says", var/datum/language/speaking = null)
	if(!on) return // the device has to be on
	//  Fix for permacell radios, but kinda eh about actually fixing them.
	if(!M || !message) return

	//  Uncommenting this. To the above comment:
	// 	The permacell radios aren't suppose to be able to transmit, this isn't a bug and this "fix" is just making radio wires useless. -Giacom
	if(!(src.wires & WIRE_TRANSMIT)) // The device has to have all its wires and shit intact
		return

	M.last_target_click = world.time

	/* Quick introduction:
		This new radio system uses a very robust FTL signaling technology unoriginally
		dubbed "subspace" which is somewhat similar to 'blue-space' but can't
		actually transmit large mass. Headsets are the only radio devices capable
		of sending subspace transmissions to the Communications Satellite.

		A headset sends a signal to a subspace listener/reciever elsewhere in space,
		the signal gets processed and logged, and an audible transmission gets sent
		to each individual headset.
	*/

	//#### Grab the connection datum ####//
	var/datum/radio_frequency/connection = handle_message_mode(M, message, channel)
	if(!istype(connection))
		return
	if(!connection)
		return

	var/turf/position = get_turf(src)
	if(QDELETED(position))
		return

	//#### Tagging the signal with all appropriate identity values ####//

	// ||-- The mob's name identity --||
	var/displayname = M.name	// grab the display name (name you get when you hover over someone's icon)
	var/real_name = M.real_name // mob's real name
	var/voicemask = 0 // the speaker is wearing a voice mask

	var/jobname // the mob's "job"
	// --- Human: use their actual job ---
	if(ishuman(M))
		jobname = M:get_assignment()
	// --- Carbon Nonhuman ---
	else if(iscarbon(M)) // Nonhuman carbon mob
		jobname = "No id"
	// --- AI ---
	else if(isAI(M))
		jobname = "AI"
	// --- Cyborg ---
	else if(isrobot(M))
		jobname = "Cyborg"
	// --- Unidentifiable mob ---
	else
		jobname = "Unknown"

	// --- Modifications to the mob's identity ---
	// The mob is disguising their identity:
	if(ishuman(M) && M.GetVoice() != real_name)
		displayname = M.GetVoice()
		jobname = "Unknown"
		voicemask = 1

	var/transmit_z = position.z
	// If the mob is inside a vehicle interior, send the message from the vehicle's z, not the interior z
	if(interior_manager && transmit_z == interior_manager.interior_z)
		var/datum/interior/I = interior_manager.get_interior_by_coords(position.x, position.y)
		if(I && I.exterior)
			transmit_z = I.exterior.z

	var/list/target_zs = list(transmit_z)
	if(ignore_z)
		target_zs = SSmapping.levels_by_trait(ZTRAIT_ADMIN) //this area always has comms

	/* ###### Intercoms and station-bounced radios ###### */
	var/filter_type = RADIO_FILTER_TYPE_INTERCOM_AND_BOUNCER
	if(subspace_transmission)
		filter_type = RADIO_FILTER_TYPE_ALL
		if(!src.ignore_z)
			target_zs = get_target_zs()
			if (isnull(target_zs))
				//We don't have a radio connection on our Z-level, abort!
				return

	/* --- Intercoms can only broadcast to other intercoms, but bounced radios can broadcast to bounced radios and intercoms --- */
	if(istype(src, /obj/item/device/radio/intercom))
		filter_type = RADIO_FILTER_TYPE_INTERCOM


	Broadcast_Message(connection, M, voicemask, pick(M.speak_emote),
					  src, message, displayname, jobname, real_name, M.voice_name,
					  filter_type, 0, target_zs, connection.frequency, verb, speaking)


/obj/item/device/radio/proc/get_target_zs()
	var/turf/position = get_turf(src)
	if(QDELETED(position))
		return

	var/transmit_z = position.z
	// If the mob is inside a vehicle interior, send the message from the vehicle's z, not the interior z
	if(interior_manager && transmit_z == interior_manager.interior_z)
		var/datum/interior/I = interior_manager.get_interior_by_coords(position.x, position.y)
		if(I && I.exterior)
			transmit_z = I.exterior.z

	var/list/target_zs = list(transmit_z)
	if(ignore_z)
		target_zs = SSmapping.levels_by_trait(ZTRAIT_ADMIN) //this area always has comms


	if(subspace_transmission)
		if(!src.ignore_z)
			target_zs = SSradio.get_available_tcomm_zs()
			if(!(transmit_z in target_zs))
				//We don't have a connection ourselves!
				return null
	return target_zs

/obj/item/device/radio/hear_talk(mob/M as mob, msg, var/verb = "says", var/datum/language/speaking = null)
	if (broadcasting)
		if(get_dist(src, M) <= canhear_range)
			talk_into(M, msg,null,verb,speaking)


/*
/obj/item/device/radio/proc/accept_rad(obj/item/device/radio/R as obj, message)

	if ((R.frequency == frequency && message))
		return 1
	else if

	else
		return null
	return
*/


/obj/item/device/radio/proc/receive_range(freq, level)
	// check if this radio can receive on the given frequency, and if so,
	// what the range is in which mobs will hear the radio
	// returns: -1 if can't receive, range otherwise

	if (!(wires & WIRE_RECEIVE))
		return -1
	if(!listening)
		return -1
	if(!(0 in level))
		var/turf/position = get_turf(src)
		if(QDELETED(position))
			return FALSE
		var/receive_z = position.z
		// Use vehicle's z if we're inside a vehicle interior
		if(interior_manager && position.z == interior_manager.interior_z)
			var/datum/interior/I = interior_manager.get_interior_by_coords(position.x, position.y)
			if(I && I.exterior)
				receive_z = I.exterior.z
		if(src.ignore_z == TRUE)
			receive_z = SSmapping.levels_by_trait(ZTRAIT_ADMIN)[1] //this area always has comms

		if(!position || !(receive_z in level))
			return -1
	if(freq in ANTAG_FREQS)
		if(!(src.syndie))//Checks to see if it's allowed on that frequency, based on the encryption keys
			return -1
	if (!on)
		return -1
	if (!freq) //recieved on main frequency
		if (!listening)
			return -1
	else
		var/accept = (freq==frequency && listening)
		if (!accept)
			for (var/ch_name in channels)
				var/datum/radio_frequency/RF = secure_radio_connections[ch_name]
				if (RF.frequency==freq && (channels[ch_name]&FREQ_LISTENING))
					accept = 1
					break
		if (!accept)
			return -1
	return canhear_range

/obj/item/device/radio/proc/send_hear(freq, level)
	var/range = receive_range(freq, level)
	if(range > -1)
		return get_mobs_in_view(canhear_range, src)


/obj/item/device/radio/examine(mob/user)
	..()
	if ((in_range(src, user) || loc == user))
		if (b_stat)
			to_chat(user, SPAN_NOTICE(" [src] can be attached and modified!"))
		else
			to_chat(user, SPAN_NOTICE(" [src] can not be modified or attached!"))


/obj/item/device/radio/attackby(obj/item/W as obj, mob/user as mob)
	..()
	user.set_interaction(src)
	if (!( istype(W, /obj/item/tool/screwdriver) ))
		return
	b_stat = !( b_stat )
	if(!istype(src, /obj/item/device/radio/beacon))
		if (b_stat)
			user.show_message(SPAN_NOTICE("The radio can now be attached and modified!"))
		else
			user.show_message(SPAN_NOTICE("The radio can no longer be modified or attached!"))
		updateDialog()
			//Foreach goto(83)
		add_fingerprint(user)
		return
	else return

/obj/item/device/radio/emp_act(severity)
	broadcasting = 0
	listening = 0
	for (var/ch_name in channels)
		channels[ch_name] = 0
	..()

///////////////////////////////
//////////Borg Radios//////////
///////////////////////////////
//Giving borgs their own radio to have some more room to work with -Sieve

/obj/item/device/radio/borg
	var/mob/living/silicon/robot/myborg = null // Cyborg which owns this radio. Used for power checks
	var/obj/item/device/encryptionkey/keyslot = null//Borg radios can handle a single encryption key
	var/shut_up = 0
	icon = 'icons/obj/items/robot_component.dmi' // Cyborgs radio icons should look like the component.
	icon_state = "radio"
	canhear_range = 3

/obj/item/device/radio/borg/talk_into()
	..()
	if (isrobot(src.loc))
		var/mob/living/silicon/robot/R = src.loc
		var/datum/robot_component/C = R.components["radio"]
		R.cell_use_power(C.active_usage)

/obj/item/device/radio/borg/attackby(obj/item/W as obj, mob/user as mob)
//	..()
	user.set_interaction(src)
	if (!( istype(W, /obj/item/tool/screwdriver) || (istype(W, /obj/item/device/encryptionkey/ ))))
		return

	if(istype(W, /obj/item/tool/screwdriver))
		if(keyslot)


			for(var/ch_name in channels)
				SSradio.remove_object(src, radiochannels[ch_name])
				secure_radio_connections[ch_name] = null


			if(keyslot)
				var/turf/T = get_turf(user)
				if(T)
					keyslot.forceMove(T)
					keyslot = null

			recalculateChannels()
			to_chat(user, "You pop out the encryption key in the radio!")

		else
			to_chat(user, "This radio doesn't have any encryption keys!")

	if(istype(W, /obj/item/device/encryptionkey/))
		if(keyslot)
			to_chat(user, "The radio can't hold another key!")
			return

		if(!keyslot)
			if(user.drop_held_item())
				W.forceMove(src)
				keyslot = W

		recalculateChannels()

	return

/obj/item/device/radio/borg/proc/recalculateChannels()
	src.channels = list()
	src.syndie = 0

	var/mob/living/silicon/robot/D = src.loc
	if(D.module)
		for(var/ch_name in D.module.channels)
			if(ch_name in src.channels)
				continue
			src.channels += ch_name
			src.channels[ch_name] += D.module.channels[ch_name]
	if(keyslot)
		for(var/ch_name in keyslot.channels)
			if(ch_name in src.channels)
				continue
			src.channels += ch_name
			src.channels[ch_name] += keyslot.channels[ch_name]

		if(keyslot.syndie)
			src.syndie = 1


	for (var/ch_name in src.channels)
		secure_radio_connections[ch_name] = SSradio.add_object(src, radiochannels[ch_name],  RADIO_CHAT)

/obj/item/device/radio/borg/Topic(href, href_list)
	if(usr.stat || !on)
		return
	if (href_list["mode"])
		if(subspace_transmission != 1)
			subspace_transmission = 1
			to_chat(usr, "Subspace Transmission is disabled")
		else
			subspace_transmission = 0
			to_chat(usr, "Subspace Transmission is enabled")
		if(subspace_transmission == 1)//Simple as fuck, clears the channel list to prevent talking/listening over them if subspace transmission is disabled
			channels = list()
		else
			recalculateChannels()
	if (href_list["shutup"]) // Toggle loudspeaker mode, AKA everyone around you hearing your radio.
		shut_up = !shut_up
		if(shut_up)
			canhear_range = 0
		else
			canhear_range = 3

	..()

/obj/item/device/radio/borg/interact(mob/user as mob)
	if(!on)
		return

	var/dat = "<html><head><title>[src]</title></head><body><TT>"
	dat += {"
				Speaker: [listening ? "<A href='byond://?src=\ref[src];listen=0'>Engaged</A>" : "<A href='byond://?src=\ref[src];listen=1'>Disengaged</A>"]<BR>
				Frequency:
				<A href='byond://?src=\ref[src];freq=-10'>-</A>
				<A href='byond://?src=\ref[src];freq=-2'>-</A>
				[format_frequency(frequency)]
				<A href='byond://?src=\ref[src];freq=2'>+</A>
				<A href='byond://?src=\ref[src];freq=10'>+</A><BR>
				<A href='byond://?src=\ref[src];mode=1'>Toggle Broadcast Mode</A><BR>
				<A href='byond://?src=\ref[src];shutup=1'>Toggle Loudspeaker</A><BR>
				"}

	if(!subspace_transmission)//Don't even bother if subspace isn't turned on
		for (var/ch_name in channels)
			dat+=text_sec_channel(ch_name, channels[ch_name])
	dat+={"[text_wires()]</TT></body></html>"}
	show_browser(user, dat, name, "radio")
	return


/obj/item/device/radio/proc/config(op)
	for (var/ch_name in channels)
		SSradio.remove_object(src, radiochannels[ch_name])
	secure_radio_connections = new
	channels = op
	for (var/ch_name in op)
		secure_radio_connections[ch_name] = SSradio.add_object(src, radiochannels[ch_name],  RADIO_CHAT)

/obj/item/device/radio/off
	listening = 0



//MARINE RADIO

/obj/item/device/radio/marine
	frequency = PUB_FREQ
