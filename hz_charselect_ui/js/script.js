// Wrap everything in DOMContentLoaded to ensure HTML is ready
document.addEventListener('DOMContentLoaded', () => {
    console.log('[DEBUG] script.js: DOMContentLoaded fired.');

    // Get references to HTML elements
    const characterContainer = document.getElementById('character-container');
    const characterSlotsDiv = document.getElementById('character-slots');
    const creationFormDiv = document.getElementById('creation-form');
    const statusMessage = document.getElementById('status-message');
    const cancelCreateButton = document.getElementById('cancel-create-button');
    const submitCreateButton = document.getElementById('submit-create-button');

    // Check if elements were found (basic check)
    if (!characterContainer || !characterSlotsDiv || !creationFormDiv || !statusMessage || !cancelCreateButton || !submitCreateButton) {
        console.error('[DEBUG] script.js: Failed to find one or more required HTML elements!');
        // Maybe display an error message in the NUI itself?
        if (statusMessage) statusMessage.textContent = "UI Error: Elements missing.";
        return; // Stop script execution if essential elements are missing
    }

    // Variable to track the slot being created
    let selectedSlot = null;

    // --- NUI Message Listener (from Lua) ---
    window.addEventListener('message', (event) => {
        const data = event.data;
        console.log('[DEBUG] script.js: NUI message received:', JSON.stringify(data));

        if (data.action === 'showUI') {
            console.log('[DEBUG] script.js: Processing showUI action.');
            populateCharacterSlots(data.characters, data.maxSlots);
            characterContainer.classList.remove('hidden');
            document.body.style.display = 'block'; // Show NUI background/container
            if (statusMessage) statusMessage.textContent = 'Select or create a character.';
        } else if (data.action === 'hideUI') {
            console.log('[DEBUG] script.js: Processing hideUI action.');
            if (statusMessage) statusMessage.textContent = ''; // Clear status on hide
            characterContainer.classList.add('hidden');
            document.body.style.display = 'none'; // Hide NUI background/container
        } else if (data.action === 'setStatus') {
            console.log('[DEBUG] script.js: Processing setStatus action.');
            if (statusMessage) statusMessage.textContent = `Status: ${data.message}`;
        }
    });

    // --- Populate UI ---
    function populateCharacterSlots(characters, maxSlots) {
        console.log('[DEBUG] Populating character slots...');
        characterSlotsDiv.innerHTML = ''; // Clear previous slots
        creationFormDiv.classList.add('hidden'); // Ensure creation form is hidden
        if (statusMessage) statusMessage.textContent = 'Select or create a character.'; // Reset status
        selectedSlot = null; // Reset creation slot tracker

        // Create a map for easy lookup of characters by slot
        const characterMap = new Map();
        if (Array.isArray(characters)) { // Check if characters is actually an array
             characters.forEach(char => characterMap.set(char.slot, char));
        } else {
            console.error('[DEBUG] Invalid character data received:', characters);
        }


        // Loop through the maximum allowed slots
        for (let i = 1; i <= maxSlots; i++) {
            const slotDiv = document.createElement('div');
            slotDiv.classList.add('character-slot');
            slotDiv.dataset.slot = i; // Store slot number

            if (characterMap.has(i)) {
                // --- Existing Character Slot ---
                const char = characterMap.get(i);
                slotDiv.innerHTML = `
                    <h3>${char.firstname || 'Unknown'} ${char.lastname || 'Name'}</h3>
                    <p>Job: ${char.job || 'Unemployed'}</p>
                    <button class="select-button" data-charid="${char.charid}">Play</button>
                    <button class="delete-button" data-charid="${char.charid}">Delete</button> <!-- Add delete later -->
                `;
                const selectBtn = slotDiv.querySelector('.select-button');
                if (selectBtn) {
                    console.log(`[DEBUG] Attaching 'Play' button listener for slot ${i} (charid: ${char.charid})`);
                    selectBtn.addEventListener('click', (e) => {
                        e.stopPropagation(); // Prevent triggering other listeners if nested
                        selectCharacter(char.charid); // Call selection function
                    });
                } else {
                    console.error(`[DEBUG] Could not find .select-button for slot ${i}`);
                }
                // TODO: Add listener for delete button later
            } else {
                // --- Empty Character Slot ---
                slotDiv.classList.add('empty');
                slotDiv.innerHTML = `
                    <h3>Slot ${i}</h3>
                    <p>(Empty)</p>
                    <button class="create-button">Create</button>
                `;
                const createBtn = slotDiv.querySelector('.create-button');
                if (createBtn) {
                     console.log(`[DEBUG] Attaching 'Create' button listener for slot ${i}`);
                     createBtn.addEventListener('click', (e) => {
                        e.stopPropagation();
                        showCreationForm(i); // Call function to show creation form
                    });
                } else {
                     console.error(`[DEBUG] Could not find .create-button for slot ${i}`);
                }
            }
            characterSlotsDiv.appendChild(slotDiv); // Add the created slot div to the container
        }
        console.log('[DEBUG] Finished populating slots.');
    }

    // --- Creation Form Handling ---
    function showCreationForm(slot) {
        console.log(`[DEBUG] Showing creation form for slot ${slot}`);
        selectedSlot = slot; // Store which slot we are creating for
        characterSlotsDiv.classList.add('hidden'); // Hide the slot selection view
        creationFormDiv.classList.remove('hidden'); // Show the creation form
        if(statusMessage) statusMessage.textContent = `Creating character in slot ${slot}...`;
        // Clear form fields
        document.getElementById('create-firstname').value = '';
        document.getElementById('create-lastname').value = '';
        document.getElementById('create-dob').value = '';
        document.getElementById('create-gender').value = '0'; // Default to Male
        document.getElementById('create-nationality').value = '';
    }

    function hideCreationForm() {
        console.log('[DEBUG] Hiding creation form.');
        selectedSlot = null; // Clear slot tracker
        creationFormDiv.classList.add('hidden'); // Hide form
        characterSlotsDiv.classList.remove('hidden'); // Show slots view again
        if(statusMessage) statusMessage.textContent = 'Select or create a character.'; // Reset status
    }

    // Attach listener to the main Cancel button in the creation form
    console.log('[DEBUG] Attaching listener for cancel-create-button');
    cancelCreateButton.addEventListener('click', hideCreationForm);

    // Attach listener to the main Submit button in the creation form
    console.log('[DEBUG] Attaching listener for submit-create-button');
    submitCreateButton.addEventListener('click', () => {
        console.log('[DEBUG] Submit Create Button Clicked!');
        if (!selectedSlot) {
             console.error('[DEBUG] Submit attempted but no slot selected.');
             return;
        }

        // Get values from form fields
        const firstName = document.getElementById('create-firstname').value.trim();
        const lastName = document.getElementById('create-lastname').value.trim();
        const dob = document.getElementById('create-dob').value; // TODO: Add validation for date format/age
        const gender = document.getElementById('create-gender').value;
        const nationality = document.getElementById('create-nationality').value.trim();

        // Basic validation
        if (!firstName || !lastName || !dob || !nationality) {
            if (statusMessage) statusMessage.textContent = 'Please fill in all required fields.';
            console.warn('[DEBUG] Character creation submission failed: Missing fields.');
            return;
        }
        if (statusMessage) statusMessage.textContent = 'Submitting character info...';

        // Send data back to Lua client script via NUI Fetch
        fetch(`https://${GetParentResourceName()}/submitCharacterInfo`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                slot: selectedSlot, // The slot number being created
                firstname: firstName,
                lastname: lastName,
                dateofbirth: dob,
                gender: parseInt(gender, 10), // Ensure gender is sent as a number
                nationality: nationality
            })
        }).then(resp => resp.json()).then(resp => {
            console.log('[DEBUG] submitCharacterInfo response:', resp);
            if (resp.success) {
                // Success! Lua side will now likely trigger the appearance editor.
                // NUI might be hidden by Lua shortly.
                if (statusMessage) statusMessage.textContent = 'Character info submitted. Loading appearance editor...';
            } else {
                // Show error message returned from Lua callback
                if (statusMessage) statusMessage.textContent = `Error: ${resp.message || 'Failed to submit character info.'}`;
            }
        }).catch(err => {
            // Handle network or other fetch errors
            if (statusMessage) statusMessage.textContent = 'Communication error sending character info.';
            console.error("[DEBUG] Fetch Error (submitCharacterInfo):", err);
        });
    });

    // --- Character Selection ---
    function selectCharacter(charid) {
        console.log(`[DEBUG] Selected character ${charid}`);
        if (statusMessage) statusMessage.textContent = `Loading character ${charid}...`;

        // Send selection back to Lua client script via NUI Fetch
         fetch(`https://${GetParentResourceName()}/selectCharacter`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ charid: charid })
        }).then(resp => resp.json()).then(resp => {
             console.log('[DEBUG] selectCharacter response:', resp);
             if (!resp.success) {
                if (statusMessage) statusMessage.textContent = `Error: ${resp.message || 'Failed to select character.'}`;
            } else {
                 // UI will be hidden by Lua once character loads fully
                 if (statusMessage) statusMessage.textContent = 'Character selected. Loading...';
            }
        }).catch(err => {
            if (statusMessage) statusMessage.textContent = 'Communication error selecting character.';
             console.error("[DEBUG] Fetch Error (selectCharacter):", err);
        });
    }

    // --- Close UI on ESC ---
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
             console.log('[DEBUG] Escape key pressed');
             // If creation form is hidden, ESC closes the whole UI
             if (creationFormDiv.classList.contains('hidden')) {
                 console.log('[DEBUG] Closing UI via ESC.');
                 fetch(`https://${GetParentResourceName()}/closeCharacterUI`, {
                     method: 'POST',
                     headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                     body: JSON.stringify({}) // Empty body, just triggering callback
                 }).then(() => console.log('[DEBUG] Close UI request sent.')).catch(err => console.error('[DEBUG] Close UI fetch failed:', err));
                 // UI hiding should be handled by Lua ('hideUI' message)
             } else {
                 // If creation form is open, ESC acts as Cancel
                 console.log('[DEBUG] Cancelling creation form via ESC.');
                hideCreationForm();
             }
        }
    });

    console.log('[DEBUG] Character UI JS Initialized and listeners attached.');

}); // End of DOMContentLoaded listener

console.log('[DEBUG] script.js: Initial script execution finished.');