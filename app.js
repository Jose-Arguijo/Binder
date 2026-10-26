(() => {
  "use strict";

  const DB_NAME = "binder-pwa";
  const DB_VERSION = 1;
  const STORE_NAME = "library";
  const STATE_KEY = "current";
  const app = document.getElementById("app");
  const modal = document.getElementById("modal");
  const toast = document.getElementById("toast");
  const icons = ["⚡", "✨", "🔥", "🌿", "☀️", "💧", "💖", "⭐", "🌙", "👑", "🏆", "🏀", "⚾", "🏈", "🎮", "📚", "🃏", "🎟️", "📦", "🪐", "🐾", "🚗", "🎵", "🌸"];
  const colors = [
    { name: "Teal", value: "#2c6f68" },
    { name: "Coral", value: "#d47a58" },
    { name: "Moss", value: "#758751" },
    { name: "Gold", value: "#bc8b42" },
    { name: "Blue", value: "#54849c" },
    { name: "Rose", value: "#b76877" }
  ];
  const legacyColorNames = { Indigo: "Teal", Mint: "Moss" };
  const conditions = ["Mint", "Near mint", "Excellent", "Lightly played", "Played", "Poor"];
  const themeIcons = { system: "◐", light: "☼", dark: "☾" };
  const money = new Intl.NumberFormat(undefined, { style: "currency", currency: "USD", maximumFractionDigits: 2 });

  let state = { collections: [], theme: "system" };
  let navigation = [];
  let searchText = "";
  let gridMode = false;
  let selectedCardID = null;
  let deferredInstallPrompt = null;
  let toastTimer = 0;
  let databasePromise;

  function id() {
    return globalThis.crypto?.randomUUID?.() ?? `binder-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  function card(name, setName, number, condition, quantity, value) {
    return { id: id(), name, setName, number, condition, quantity, value, notes: "", photo: "" };
  }

  function seedLibrary() {
    const holos = {
      id: id(), name: "First Edition Holos", icon: "✨", color: "Gold", cards: [
        card("Charizard", "Base Set", "4/102", "Lightly played", 1, 385),
        card("Blastoise", "Base Set", "2/102", "Near mint", 1, 145)
      ], children: []
    };
    const baseSet = {
      id: id(), name: "Base Set", icon: "📚", color: "Coral", cards: [
        card("Pikachu", "Base Set", "58/102", "Near mint", 3, 12),
        card("Ninetales", "Base Set", "12/102", "Excellent", 1, 8.5)
      ], children: [holos]
    };
    return [
      { id: id(), name: "Pokémon", icon: "⚡", color: "Coral", cards: [card("Eevee", "Twilight Masquerade", "188/167", "Near mint", 2, 7.25)], children: [baseSet] },
      { id: id(), name: "Magic: The Gathering", icon: "🔥", color: "Teal", cards: [
        card("Sol Ring", "Commander Masters", "396", "Near mint", 2, 3.75),
        card("The One Ring", "Tales of Middle-earth", "246", "Near mint", 1, 72)
      ], children: [] },
      { id: id(), name: "Basketball", icon: "🏀", color: "Moss", cards: [card("Rookie Season", "Courtside", "RC-12", "Excellent", 1, 28)], children: [] }
    ];
  }

  function openDatabase() {
    if (!("indexedDB" in window)) return Promise.resolve(null);
    return new Promise((resolve) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = () => {
        if (!request.result.objectStoreNames.contains(STORE_NAME)) request.result.createObjectStore(STORE_NAME);
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => resolve(null);
      request.onblocked = () => resolve(null);
    });
  }

  async function readPersistedState() {
    databasePromise = openDatabase();
    const db = await databasePromise;
    if (db) {
      const saved = await new Promise((resolve) => {
        const request = db.transaction(STORE_NAME, "readonly").objectStore(STORE_NAME).get(STATE_KEY);
        request.onsuccess = () => resolve(request.result ?? null);
        request.onerror = () => resolve(null);
      });
      if (saved && Array.isArray(saved.collections)) return saved;
    }
    try {
      const fallback = JSON.parse(localStorage.getItem("binder-library") ?? "null");
      if (fallback && Array.isArray(fallback.collections)) return fallback;
    } catch { /* Use the starter library if local storage is unavailable. */ }
    return { collections: seedLibrary(), theme: "system" };
  }

  async function persist() {
    const snapshot = structuredCloneSafe(state);
    try {
      const db = await (databasePromise ?? (databasePromise = openDatabase()));
      if (db) {
        await new Promise((resolve, reject) => {
          const transaction = db.transaction(STORE_NAME, "readwrite");
          transaction.objectStore(STORE_NAME).put(snapshot, STATE_KEY);
          transaction.oncomplete = resolve;
          transaction.onerror = () => reject(transaction.error);
          transaction.onabort = () => reject(transaction.error);
        });
      } else {
        localStorage.setItem("binder-library", JSON.stringify(snapshot));
      }
    } catch {
      showToast("Binder could not save. Check your device storage.");
    }
  }

  function structuredCloneSafe(value) {
    if (typeof structuredClone === "function") return structuredClone(value);
    return JSON.parse(JSON.stringify(value));
  }

  function escapeHTML(value) {
    return String(value ?? "").replace(/[&<>"']/g, (character) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[character]);
  }

  function cssColor(name) {
    const canonicalName = legacyColorNames[name] ?? name;
    return colors.find((item) => item.name === canonicalName)?.value ?? colors[0].value;
  }

  function migrateCollectionColors(list) {
    let changed = false;
    for (const collection of list) {
      if (legacyColorNames[collection.color]) {
        collection.color = legacyColorNames[collection.color];
        changed = true;
      }
      changed = migrateCollectionColors(collection.children ?? []) || changed;
    }
    return changed;
  }

  function countCards(collection) {
    return collection.cards.reduce((total, item) => total + Math.max(0, Number(item.quantity) || 0), 0)
      + collection.children.reduce((total, child) => total + countCards(child), 0);
  }

  function collectionValue(collection) {
    return collection.cards.reduce((total, item) => total + Math.max(0, Number(item.value) || 0) * Math.max(0, Number(item.quantity) || 0), 0)
      + collection.children.reduce((total, child) => total + collectionValue(child), 0);
  }

  function findCollection(targetID, list = state.collections) {
    for (const collection of list) {
      if (collection.id === targetID) return collection;
      const found = findCollection(targetID, collection.children);
      if (found) return found;
    }
    return null;
  }

  function findParent(targetID, list = state.collections, parent = null) {
    for (const collection of list) {
      if (collection.id === targetID) return parent;
      const found = findParent(targetID, collection.children, collection);
      if (found) return found;
    }
    return null;
  }

  function findPath(targetID, list = state.collections, path = []) {
    for (const collection of list) {
      const next = [...path, collection.id];
      if (collection.id === targetID) return next;
      const found = findPath(targetID, collection.children, next);
      if (found.length) return found;
    }
    return [];
  }

  function flatten(list = state.collections, depth = 0) {
    return list.flatMap((collection) => [{ collection, depth }, ...flatten(collection.children, depth + 1)]);
  }

  function descendants(collection) {
    return collection.children.flatMap((child) => [child.id, ...descendants(child)]);
  }

  function updateCollection(targetID, change) {
    const visit = (list) => {
      for (const collection of list) {
        if (collection.id === targetID) {
          change(collection);
          return true;
        }
        if (visit(collection.children)) return true;
      }
      return false;
    };
    visit(state.collections);
  }

  function removeCollection(targetID, list = state.collections) {
    const index = list.findIndex((collection) => collection.id === targetID);
    if (index >= 0) {
      list.splice(index, 1);
      return true;
    }
    return list.some((collection) => removeCollection(targetID, collection.children));
  }

  function totalCards() { return state.collections.reduce((sum, collection) => sum + countCards(collection), 0); }
  function totalValue() { return state.collections.reduce((sum, collection) => sum + collectionValue(collection), 0); }
  function moneyText(value) { return money.format(Number(value) || 0); }

  function applyTheme() {
    document.documentElement.dataset.theme = state.theme;
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", state.theme === "dark" ? "#171d1b" : "#2c6f68");
  }

  function brandHeader() {
    return `<header class="topbar">
      <a class="brand" href="#home" aria-label="Binder home"><span class="brand-mark" aria-hidden="true">▤</span><span>BINDER</span></a>
      <div class="top-actions">
        <button class="icon-button" data-action="theme" aria-label="Change appearance" title="Appearance: ${escapeHTML(state.theme)}">${themeIcons[state.theme]}</button>
        <button class="icon-button" data-action="install" aria-label="Install Binder" title="Install Binder">⇩</button>
      </div>
    </header>`;
  }

  function collectionRow(collection) {
    const color = cssColor(collection.color);
    const children = collection.children.length;
    const childLabel = children ? `<span class="meta-dot"></span><span>${children} shelf${children === 1 ? "" : "s"}</span>` : "";
    return `<div class="row-wrap" style="--row-color:${color}">
      <button class="collection-row" data-open-collection="${escapeHTML(collection.id)}" aria-label="Open ${escapeHTML(collection.name)}">
        <span class="collection-icon" aria-hidden="true">${escapeHTML(collection.icon)}</span>
        <span class="collection-copy">
          <span class="collection-name">${escapeHTML(collection.name)}</span>
          <span class="collection-meta"><span>${countCards(collection)} cards</span><span class="meta-dot"></span><span>${moneyText(collectionValue(collection))}</span>${childLabel}</span>
        </span>
        <span class="row-chevron" aria-hidden="true">›</span>
      </button>
      <button class="row-menu" data-collection-actions="${escapeHTML(collection.id)}" aria-label="Actions for ${escapeHTML(collection.name)}" title="Collection options">···</button>
    </div>`;
  }

  function emptyState(title, detail, action, icon = "▤") {
    return `<section class="empty-state"><span class="empty-icon" aria-hidden="true">${icon}</span><h3>${title}</h3><p>${detail}</p>${action ? `<button class="button" data-action="${action}">＋ ${action === "new-root" ? "Create collection" : "Add a card"}</button>` : ""}</section>`;
  }

  function renderLoading() {
    applyTheme();
    app.innerHTML = `<header class="topbar" aria-hidden="true"><span class="brand"><span class="brand-mark">▤</span><span>BINDER</span></span><span class="skeleton skeleton-avatar"></span></header>
      <main class="page-main home-main loading-page" aria-busy="true" aria-label="Loading your library">
        <section class="hero"><div class="hero-copy"><span class="skeleton skeleton-copy"></span><span class="skeleton skeleton-title"></span><span class="skeleton skeleton-copy"></span></div><span class="skeleton skeleton-panel"></span></section>
        <section><span class="skeleton skeleton-label"></span><div class="collection-list"><span class="skeleton skeleton-row"></span><span class="skeleton skeleton-row"></span><span class="skeleton skeleton-row"></span></div></section>
      </main>`;
  }

  function renderHome() {
    const rows = state.collections.map(collectionRow).join("");
    const collections = state.collections.length
      ? `<div class="collection-list home-list">${rows}</div>`
      : emptyState("A fresh start", "Create a collection to start cataloging your cards.", "new-root");
    app.innerHTML = `${brandHeader()}
      <main class="page-main home-main">
        <section class="hero">
          <div class="hero-copy"><div class="eyebrow"><span aria-hidden="true">✦</span> A home for the things you collect</div><h1>Your collection,<br>beautifully kept.</h1><p>Keep every card close, from the first pull to your rarest find.</p></div>
          <div class="overview" aria-label="Binder totals">
            <div class="overview-stat"><span class="eyebrow">IN YOUR BINDER</span><strong>${totalCards()}</strong><span>cards collected</span></div>
            <div class="overview-divider"></div>
            <div class="overview-stat"><span class="eyebrow">ESTIMATED VALUE</span><strong>${moneyText(totalValue())}</strong><span>across all collections</span></div>
          </div>
        </section>
        <section>
          <div class="section-heading"><div><h2>Collections</h2><p>Your shelves, all in one place</p></div><button class="button small" data-action="new-root" aria-label="Add collection">＋ Add</button></div>
          ${collections}
        </section>
        <p class="privacy-note"><span aria-hidden="true">▣</span> Your collection stays on this device</p>
      </main>`;
  }

  function breadcrumbHTML(collection) {
    const names = navigation.map((idValue) => findCollection(idValue)?.name).filter(Boolean);
    return names.map((name, index) => `${index ? `<span aria-hidden="true"> / </span>` : ""}${index === names.length - 1 ? `<strong>${escapeHTML(name)}</strong>` : escapeHTML(name)}`).join("");
  }

  function cardFaceHTML(cardItem, collection, compact = false) {
    const photo = cardItem.photo
      ? `<img class="card-photo" src="${escapeHTML(cardItem.photo)}" alt="" loading="lazy"><span class="photo-shade"></span>`
      : "";
    const quantity = Number(cardItem.quantity) > 1 ? `<span class="quantity-pill">×${Number(cardItem.quantity)}</span>` : "";
    return `<button class="card-face" data-card-id="${escapeHTML(cardItem.id)}" data-symbol="${escapeHTML(collection.icon)}" style="--card-color:${cssColor(collection.color)}" aria-label="Edit ${escapeHTML(cardItem.name || "untitled card")}">
      ${photo}<span class="card-topline"><span aria-hidden="true">${escapeHTML(collection.icon)}</span><span class="card-collection">${escapeHTML(collection.name)}</span>${quantity}</span>
      <span class="card-title">${escapeHTML(cardItem.name || "Untitled card")}</span>
      <span class="card-set">${escapeHTML(cardItem.setName || "Unsorted")}${cardItem.number ? ` · ${escapeHTML(cardItem.number)}` : ""}</span>
      <span class="card-bottom"><span>${escapeHTML(cardItem.condition || "Near mint")}</span><strong>${moneyText(cardItem.value)}</strong></span>
    </button>`;
  }

  function searchResults(collection) {
    const query = searchText.trim().toLocaleLowerCase();
    if (!query) return collection.cards;
    return collection.cards.filter((cardItem) => [cardItem.name, cardItem.setName, cardItem.number, cardItem.condition, cardItem.notes]
      .some((value) => String(value ?? "").toLocaleLowerCase().includes(query)));
  }

  function renderCollection(collection) {
    const color = cssColor(collection.color);
    const rows = collection.children.map(collectionRow).join("");
    const cards = searchResults(collection);
    const cardCount = cards.reduce((sum, cardItem) => sum + (Number(cardItem.quantity) || 0), 0);
    const currentIndex = Math.max(0, cards.findIndex((item) => item.id === selectedCardID));
    const cardBody = cards.length
      ? (gridMode
        ? `<div class="grid-cards">${cards.map((item) => cardFaceHTML(item, collection, true)).join("")}</div>`
        : `<div class="carousel-wrap"><div class="carousel" id="carousel">${cards.map((item) => `<div class="card-slide" data-slide-id="${escapeHTML(item.id)}">${cardFaceHTML(item, collection)}</div>`).join("")}</div></div>`)
      : emptyState(searchText ? "No cards found" : "This shelf is waiting", searchText ? "Try a different name, set, number or note." : "Add a card to start filling this collection.", searchText ? "" : "new-card", searchText ? "⌕" : "▱");

    app.innerHTML = `${brandHeader()}
      <main class="page-main collection-main">
        <div class="detail-topline">
          <button class="back-button" data-action="back" aria-label="Go back">‹</button>
          <div class="breadcrumb">${breadcrumbHTML(collection)}</div>
          <div class="detail-actions">
            <button class="icon-button" data-action="new-child" aria-label="Add subcollection" title="Add subcollection">＋</button>
            <button class="icon-button" data-collection-actions="${escapeHTML(collection.id)}" aria-label="Collection options" title="Collection options">···</button>
          </div>
        </div>
        <section class="collection-summary" style="--row-color:${color}">
          <span class="collection-icon" aria-hidden="true">${escapeHTML(collection.icon)}</span>
          <div class="summary-copy"><h1>${escapeHTML(collection.name)}</h1><p>${countCards(collection)} cards · ${collection.children.length} subcollection${collection.children.length === 1 ? "" : "s"}</p></div>
          <div class="summary-value"><span class="eyebrow">VALUE</span><strong>${moneyText(collectionValue(collection))}</strong></div>
        </section>
        ${collection.children.length ? `<section class="subcollections"><div class="section-heading"><div><h2>Subcollections</h2><p>${collection.children.length} shelves inside</p></div></div><div class="collection-list">${rows}</div></section>` : ""}
        <section class="cards-section">
          <div class="cards-head">
            <div><h2>${searchText ? "SEARCH RESULTS" : "CARDS"}</h2><p>${cardCount} card${cardCount === 1 ? "" : "s"}</p></div>
            <div class="cards-head-tools">
              ${cards.length && !gridMode ? `<span class="card-counter" id="card-counter">${currentIndex + 1} / ${cards.length}</span>` : ""}
              <div class="view-toggle" aria-label="Card layout"><button data-action="carousel" aria-pressed="${!gridMode}" aria-label="Carousel view" title="Carousel">▱</button><button data-action="grid" aria-pressed="${gridMode}" aria-label="Grid view" title="Grid">▦</button></div>
            </div>
          </div>
          <label class="search-field"><span aria-hidden="true">⌕</span><input id="card-search" type="search" placeholder="Search cards in ${escapeHTML(collection.name)}" value="${escapeHTML(searchText)}" autocomplete="off" aria-label="Search cards in ${escapeHTML(collection.name)}"></label>
          ${cardBody}
          ${cards.length ? `<button class="button soft add-card-wide" data-action="new-card">＋ Add a card</button>` : ""}
        </section>
        <p class="footer-note">Values are estimates based on the price and quantity you enter.</p>
      </main>`;

    if (!gridMode && cards.length) {
      const carousel = document.getElementById("carousel");
      const initial = carousel.querySelector(`[data-slide-id="${CSS.escape(selectedCardID ?? cards[0].id)}"]`);
      if (initial) requestAnimationFrame(() => {
        carousel.scrollLeft = initial.offsetLeft - (carousel.clientWidth - initial.clientWidth) / 2;
        updateCarouselEffects();
      });
      updateCarouselEffects();
      carousel.addEventListener("scroll", updateCarouselEffects, { passive: true });
    }
  }

  function render() {
    applyTheme();
    const idValue = navigation[navigation.length - 1];
    const collection = idValue ? findCollection(idValue) : null;
    if (idValue && !collection) navigation = [];
    if (collection) renderCollection(collection);
    else renderHome();
  }

  function updateCarouselEffects() {
    const carousel = document.getElementById("carousel");
    if (!carousel) return;
    const bounds = carousel.getBoundingClientRect();
    const center = bounds.left + bounds.width / 2;
    let nearest = null;
    let nearestDistance = Number.POSITIVE_INFINITY;
    carousel.querySelectorAll(".card-slide").forEach((slide) => {
      const rect = slide.getBoundingClientRect();
      const delta = rect.left + rect.width / 2 - center;
      const distance = Math.min(1, Math.abs(delta) / Math.max(bounds.width * .52, 1));
      slide.style.transform = `scale(${1 - distance * .1}) rotate(${Math.sign(delta) * distance * 7}deg)`;
      slide.style.opacity = String(1 - distance * .23);
      if (Math.abs(delta) < nearestDistance) {
        nearestDistance = Math.abs(delta);
        nearest = slide;
      }
    });
    if (nearest) {
      selectedCardID = nearest.dataset.slideId;
      const cards = document.querySelectorAll(".card-slide");
      const index = [...cards].indexOf(nearest);
      const counter = document.getElementById("card-counter");
      if (counter) counter.textContent = `${index + 1} / ${cards.length}`;
    }
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.add("visible");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => toast.classList.remove("visible"), 2400);
  }

  function openModal(title, body) {
    modal.innerHTML = `<div class="modal-content"><header class="modal-head"><h2>${title}</h2><button class="modal-close" type="button" data-modal-action="close" aria-label="Close">×</button></header>${body}</div>`;
    if (!modal.open) modal.showModal();
  }

  function closeModal() {
    if (modal.open) modal.close();
  }

  function iconPalette(selected) {
    return icons.map((icon) => `<button type="button" class="icon-choice" data-icon="${escapeHTML(icon)}" aria-pressed="${icon === selected}" aria-label="Choose ${escapeHTML(icon)}">${escapeHTML(icon)}</button>`).join("");
  }

  function colorPalette(selected) {
    return colors.map((color) => `<button type="button" class="color-choice" data-color="${escapeHTML(color.name)}" aria-pressed="${color.name === selected}" style="background:${color.value}" aria-label="${escapeHTML(color.name)}"></button>`).join("");
  }

  function attachInlineValidation(form, rules) {
    const messageFor = (input) => rules[input.name]?.(input.value) ?? "";
    const update = (input, force = false) => {
      if (!input || !Object.hasOwn(rules, input.name)) return "";
      if (!force && input.dataset.touched !== "true") return "";
      const message = messageFor(input);
      const wrapper = input.closest(".form-field");
      const errorID = `${form.id}-${input.name}-error`;
      let error = wrapper?.querySelector(`#${CSS.escape(errorID)}`);
      wrapper?.classList.toggle("invalid", Boolean(message));
      if (message) {
        input.setAttribute("aria-invalid", "true");
        input.setAttribute("aria-describedby", errorID);
        if (!error && wrapper) {
          wrapper.insertAdjacentHTML("beforeend", `<span class="field-error" id="${errorID}">${escapeHTML(message)}</span>`);
          error = wrapper.querySelector(`#${CSS.escape(errorID)}`);
        } else if (error) {
          error.textContent = message;
        }
      } else {
        input.removeAttribute("aria-invalid");
        input.removeAttribute("aria-describedby");
        error?.remove();
      }
      return message;
    };

    form.addEventListener("focusout", (event) => {
      if (!Object.hasOwn(rules, event.target.name)) return;
      event.target.dataset.touched = "true";
      update(event.target, true);
    });
    form.addEventListener("input", (event) => {
      if (!Object.hasOwn(rules, event.target.name)) return;
      if (event.target.dataset.touched === "true") update(event.target, true);
    });

    return () => {
      let firstInvalid = null;
      for (const name of Object.keys(rules)) {
        const input = form.querySelector(`[name="${name}"]`);
        if (!input) continue;
        input.dataset.touched = "true";
        if (update(input, true) && !firstInvalid) firstInvalid = input;
      }
      firstInvalid?.focus();
      return !firstInvalid;
    };
  }

  function openCollectionEditor(existing = null, parentID = null) {
    const creating = !existing;
    const draft = existing ? { ...existing, color: legacyColorNames[existing.color] ?? existing.color } : { id: id(), name: "", icon: "✨", color: "Teal", cards: [], children: [] };
    const parentLabel = parentID ? findCollection(parentID)?.name : "Top level";
    openModal(creating ? "New collection" : "Edit collection", `<form id="collection-form" class="form-stack" novalidate>
      <label class="form-field">Name<input name="name" maxlength="48" required aria-required="true" placeholder="Collection name" value="${escapeHTML(draft.name)}" autocomplete="off"></label>
      <div class="form-field">Icon<div class="icon-palette" id="icon-palette">${iconPalette(draft.icon)}</div><input type="hidden" name="icon" value="${escapeHTML(draft.icon)}"></div>
      <div class="form-field">Color<div class="color-palette" id="color-palette">${colorPalette(draft.color)}</div><input type="hidden" name="color" value="${escapeHTML(draft.color)}"></div>
      ${creating ? `<p class="form-hint">This shelf will be saved under <strong>${escapeHTML(parentLabel)}</strong>.</p>` : ""}
      <div class="form-actions-end"><button class="button secondary" type="button" data-modal-action="close">Cancel</button><button class="button" type="submit">Save collection</button></div>
    </form>`);
    const form = document.getElementById("collection-form");
    const validate = attachInlineValidation(form, { name: (value) => value.trim() ? "" : "Give this collection a name." });
    form.addEventListener("click", (event) => {
      const iconButton = event.target.closest("[data-icon]");
      const colorButton = event.target.closest("[data-color]");
      if (iconButton) {
        form.elements.icon.value = iconButton.dataset.icon;
        form.querySelectorAll("[data-icon]").forEach((item) => item.setAttribute("aria-pressed", String(item === iconButton)));
      }
      if (colorButton) {
        form.elements.color.value = colorButton.dataset.color;
        form.querySelectorAll("[data-color]").forEach((item) => item.setAttribute("aria-pressed", String(item === colorButton)));
      }
    });
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!validate()) return;
      draft.name = form.elements.name.value.trim();
      draft.icon = form.elements.icon.value;
      draft.color = form.elements.color.value;
      if (!draft.name) return;
      if (creating) {
        if (parentID) updateCollection(parentID, (parent) => parent.children.push(draft));
        else state.collections.push(draft);
      } else {
        const replacement = { ...existing, name: draft.name, icon: draft.icon, color: draft.color };
        updateCollection(existing.id, (target) => Object.assign(target, replacement));
      }
      closeModal();
      await persist();
      render();
      showToast(creating ? "Collection created" : "Collection updated");
    });
  }

  function openCardEditor(collection, existing = null) {
    const creating = !existing;
    const draft = existing ? { ...existing } : { id: id(), name: "", setName: "", number: "", condition: "Near mint", quantity: 1, value: 0, notes: "", photo: "" };
    const preview = draft.photo
      ? `<span class="photo-preview"><img src="${escapeHTML(draft.photo)}" alt="Card photo preview"></span>`
      : `<div class="card-face photo-preview" data-symbol="${escapeHTML(collection.icon)}" style="--card-color:${cssColor(collection.color)}"><span class="card-topline">${escapeHTML(collection.icon)} <span>${escapeHTML(collection.name)}</span></span><span class="card-title">${escapeHTML(draft.name || "Your card")}</span><span class="card-set">${escapeHTML(draft.setName || "Generated card face")}</span></div>`;
    openModal(creating ? "Add a card" : "Card details", `<form id="card-form" class="form-stack" novalidate>
      <div id="photo-preview">${preview}</div>
      <div class="photo-actions"><label class="button secondary small" for="card-photo">${draft.photo ? "Replace photo" : "Choose photo"}</label><input class="sr-only" id="card-photo" name="photo" type="file" accept="image/*">${draft.photo ? `<button type="button" class="button ghost small" data-card-action="remove-photo">Remove</button>` : ""}</div>
      <p class="form-hint">Without a photo, Binder makes a color-matched face with your collection icon.</p>
      <label class="form-field">Card name<input name="name" required aria-required="true" maxlength="80" placeholder="Card name" value="${escapeHTML(draft.name)}" autocomplete="off"></label>
      <div class="field-row"><label class="form-field">Set<input name="setName" maxlength="80" placeholder="Set name" value="${escapeHTML(draft.setName)}"></label><label class="form-field">Number<input name="number" maxlength="30" placeholder="e.g. 4/102" value="${escapeHTML(draft.number)}"></label></div>
      <div class="field-row"><label class="form-field">Condition<select name="condition">${conditions.map((value) => `<option ${value === draft.condition ? "selected" : ""}>${escapeHTML(value)}</option>`).join("")}</select></label><label class="form-field">Quantity<input name="quantity" type="number" min="1" max="999" step="1" required aria-required="true" value="${Math.max(1, Number(draft.quantity) || 1)}"></label></div>
      <label class="form-field">Value each<input name="value" type="number" min="0" step="0.01" inputmode="decimal" placeholder="0.00" value="${Number(draft.value) || ""}"></label>
      <label class="form-field">Notes<textarea name="notes" maxlength="1500" placeholder="Add a note about this card…">${escapeHTML(draft.notes)}</textarea></label>
      <div class="form-actions">${creating ? `<span></span>` : `<button class="button danger small" type="button" data-card-action="delete">Delete card</button>`}<div class="form-action-buttons"><button class="button secondary" type="button" data-modal-action="close">Cancel</button><button class="button" type="submit">Save card</button></div></div>
    </form>`);
    const form = document.getElementById("card-form");
    const validate = attachInlineValidation(form, {
      name: (value) => value.trim() ? "" : "Add a card name before saving.",
      quantity: (value) => {
        const quantity = Number(value);
        if (!value.trim()) return "Enter the number of copies you have.";
        if (!Number.isInteger(quantity) || quantity < 1 || quantity > 999) return "Use a whole number from 1 to 999.";
        return "";
      },
      value: (value) => {
        if (!value.trim()) return "";
        const amount = Number(value);
        return Number.isFinite(amount) && amount >= 0 ? "" : "Enter a value of $0 or more.";
      }
    });
    form.addEventListener("input", (event) => {
      if (event.target.name === "name" || event.target.name === "setName") {
        const title = form.querySelector(".card-title");
        const set = form.querySelector(".card-set");
        if (title) title.textContent = form.elements.name.value || "Your card";
        if (set) set.textContent = form.elements.setName.value || "Generated card face";
      }
    });
    form.addEventListener("change", async (event) => {
      if (event.target.name !== "photo" || !event.target.files?.[0]) return;
      try {
        draft.photo = await optimizePhoto(event.target.files[0]);
        const holder = document.getElementById("photo-preview");
        holder.innerHTML = `<span class="photo-preview"><img src="${escapeHTML(draft.photo)}" alt="Card photo preview"></span>`;
        const actions = form.querySelector(".photo-actions");
        if (!actions.querySelector('[data-card-action="remove-photo"]')) actions.insertAdjacentHTML("beforeend", '<button type="button" class="button ghost small" data-card-action="remove-photo">Remove</button>');
      } catch {
        showToast("Could not load that photo");
      }
    });
    form.addEventListener("click", async (event) => {
      const action = event.target.closest("[data-card-action]")?.dataset.cardAction;
      if (action === "remove-photo") {
        draft.photo = "";
        const holder = document.getElementById("photo-preview");
        holder.innerHTML = `<div class="card-face photo-preview" data-symbol="${escapeHTML(collection.icon)}" style="--card-color:${cssColor(collection.color)}"><span class="card-topline">${escapeHTML(collection.icon)} <span>${escapeHTML(collection.name)}</span></span><span class="card-title">${escapeHTML(form.elements.name.value || "Your card")}</span><span class="card-set">${escapeHTML(form.elements.setName.value || "Generated card face")}</span></div>`;
        form.querySelector('[data-card-action="remove-photo"]')?.remove();
        form.elements.photo.value = "";
      }
      if (action === "delete" && window.confirm(`Delete ${existing.name || "this card"}?`)) {
        updateCollection(collection.id, (target) => { target.cards = target.cards.filter((item) => item.id !== existing.id); });
        closeModal();
        await persist();
        render();
        showToast("Card deleted");
      }
    });
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!validate()) return;
      const values = new FormData(form);
      const name = String(values.get("name") ?? "").trim();
      if (!name) return;
      const nextCard = {
        ...draft,
        name,
        setName: String(values.get("setName") ?? "").trim(),
        number: String(values.get("number") ?? "").trim(),
        condition: String(values.get("condition") ?? "Near mint"),
        quantity: Math.min(999, Math.max(1, Number.parseInt(String(values.get("quantity")), 10) || 1)),
        value: Math.max(0, Number.parseFloat(String(values.get("value") ?? "0")) || 0),
        notes: String(values.get("notes") ?? "").trim()
      };
      updateCollection(collection.id, (target) => {
        const index = target.cards.findIndex((item) => item.id === nextCard.id);
        if (index < 0) target.cards.push(nextCard);
        else target.cards[index] = nextCard;
      });
      closeModal();
      await persist();
      render();
      showToast(creating ? "Card added" : "Card updated");
    });
  }

  async function optimizePhoto(file) {
    const source = URL.createObjectURL(file);
    try {
      const image = new Image();
      image.src = source;
      await image.decode();
      const scale = Math.min(1, 1600 / Math.max(image.naturalWidth, image.naturalHeight));
      const canvas = document.createElement("canvas");
      canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
      canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
      canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height);
      return canvas.toDataURL("image/jpeg", .82);
    } finally {
      URL.revokeObjectURL(source);
    }
  }

  function openCollectionActions(targetID) {
    const collection = findCollection(targetID);
    if (!collection) return;
    openModal(escapeHTML(collection.name), `<div class="form-stack">
      <button class="button secondary" data-collection-action="edit" data-id="${escapeHTML(targetID)}">✎ &nbsp; Edit collection</button>
      <button class="button secondary" data-collection-action="move" data-id="${escapeHTML(targetID)}">↗ &nbsp; Move collection</button>
      <button class="button danger" data-collection-action="delete" data-id="${escapeHTML(targetID)}">⌫ &nbsp; Delete collection</button>
    </div>`);
  }

  function openMoveCollection(targetID) {
    const moving = findCollection(targetID);
    if (!moving) return;
    const oldParent = findParent(targetID);
    let destination = oldParent?.id ?? "root";
    const excluded = new Set([targetID, ...descendants(moving)]);
    const choices = [{ collection: null, depth: 0 }, ...flatten().filter((item) => !excluded.has(item.collection.id))];
    const choiceHTML = choices.map((item) => {
      const isRoot = !item.collection;
      const idValue = isRoot ? "root" : item.collection.id;
      const label = isRoot ? "Top level" : item.collection.name;
      const icon = isRoot ? "▤" : item.collection.icon;
      const color = isRoot ? "#858497" : cssColor(item.collection.color);
      return `<button type="button" class="move-choice ${idValue === destination ? "selected" : ""}" data-destination="${escapeHTML(idValue)}" style="--indent:${(item.depth || 0) * 16}px"><span class="collection-icon move-icon" style="--row-color:${color}">${escapeHTML(icon)}</span><span class="move-name">${escapeHTML(label)}</span><span class="move-check">${idValue === destination ? "✓" : ""}</span></button>`;
    }).join("");
    openModal("Move collection", `<div class="form-stack"><p class="form-hint">Choose a new parent for <strong>${escapeHTML(moving.name)}</strong>. Its cards and nested shelves move with it.</p><div class="move-list" id="move-list">${choiceHTML}</div><div class="form-actions-end"><button class="button secondary" data-modal-action="close">Cancel</button><button id="confirm-move" class="button">Move here</button></div></div>`);
    document.getElementById("move-list").addEventListener("click", (event) => {
      const choice = event.target.closest("[data-destination]");
      if (!choice) return;
      destination = choice.dataset.destination;
      document.querySelectorAll(".move-choice").forEach((button) => {
        button.classList.toggle("selected", button === choice);
        button.querySelector(".move-check").textContent = button === choice ? "✓" : "";
      });
      document.getElementById("confirm-move").disabled = destination === (oldParent?.id ?? "root");
    });
    const confirm = document.getElementById("confirm-move");
    confirm.disabled = true;
    confirm.addEventListener("click", async () => {
      if (destination === (oldParent?.id ?? "root")) return;
      let movingItem = null;
      const detach = (list) => {
        const index = list.findIndex((item) => item.id === targetID);
        if (index >= 0) { [movingItem] = list.splice(index, 1); return true; }
        return list.some((item) => detach(item.children));
      };
      detach(state.collections);
      if (!movingItem) return;
      if (destination === "root") state.collections.push(movingItem);
      else updateCollection(destination, (parent) => parent.children.push(movingItem));
      if (navigation.some((navID) => navID === targetID || descendants(movingItem).includes(navID))) navigation = findPath(targetID);
      closeModal();
      await persist();
      render();
      showToast("Collection moved");
    });
  }

  async function deleteCollection(targetID) {
    const collection = findCollection(targetID);
    if (!collection) return;
    const parent = findParent(targetID);
    const oldPath = navigation.slice();
    const affected = new Set([targetID, ...descendants(collection)]);
    if (!window.confirm(`Delete “${collection.name}” and everything inside it? This cannot be undone.`)) return;
    removeCollection(targetID);
    if (oldPath.some((navID) => affected.has(navID))) navigation = parent ? findPath(parent.id) : [];
    closeModal();
    history.replaceState({ binder: true }, "", navigation.length ? `#collection/${navigation[navigation.length - 1]}` : "#home");
    await persist();
    render();
    showToast("Collection deleted");
  }

  function navigateToCollection(targetID) {
    if (!findCollection(targetID)) return;
    navigation = findPath(targetID);
    searchText = "";
    gridMode = false;
    selectedCardID = findCollection(targetID)?.cards[0]?.id ?? null;
    history.pushState({ binder: true }, "", `#collection/${targetID}`);
    render();
  }

  function restoreNavigationFromURL() {
    const match = location.hash.match(/^#collection\/(.+)$/);
    navigation = match ? findPath(decodeURIComponent(match[1])) : [];
    if (!navigation.length) history.replaceState({ binder: true }, "", "#home");
  }

  async function handleInstall() {
    if (deferredInstallPrompt) {
      deferredInstallPrompt.prompt();
      const result = await deferredInstallPrompt.userChoice;
      if (result?.outcome === "accepted") showToast("Binder is being installed");
      deferredInstallPrompt = null;
      return;
    }
    showToast(/iphone|ipad|ipod/i.test(navigator.userAgent)
      ? "To install, tap Share, then Add to Home Screen."
      : "Use your browser’s Install app option to add Binder to your device.");
  }

  app.addEventListener("click", async (event) => {
    const openButton = event.target.closest("[data-open-collection]");
    if (openButton) { navigateToCollection(openButton.dataset.openCollection); return; }
    const actionsButton = event.target.closest("[data-collection-actions]");
    if (actionsButton) { openCollectionActions(actionsButton.dataset.collectionActions); return; }
    const cardButton = event.target.closest("[data-card-id]");
    if (cardButton) {
      const collection = findCollection(navigation[navigation.length - 1]);
      const targetCard = collection?.cards.find((item) => item.id === cardButton.dataset.cardId);
      if (collection && targetCard) openCardEditor(collection, targetCard);
      return;
    }
    const action = event.target.closest("[data-action]")?.dataset.action;
    if (!action) return;
    if (action === "new-root") openCollectionEditor();
    if (action === "new-child") openCollectionEditor(null, navigation[navigation.length - 1]);
    if (action === "new-card") {
      const collection = findCollection(navigation[navigation.length - 1]);
      if (collection) openCardEditor(collection);
    }
    if (action === "theme") {
      const themes = ["system", "light", "dark"];
      state.theme = themes[(themes.indexOf(state.theme) + 1) % themes.length];
      await persist();
      render();
      showToast(`Appearance: ${state.theme}`);
    }
    if (action === "install") handleInstall();
    if (action === "grid" || action === "carousel") {
      gridMode = action === "grid";
      const currentID = navigation[navigation.length - 1];
      const input = document.getElementById("card-search");
      searchText = input?.value ?? searchText;
      render();
    }
    if (action === "back") {
      navigation = navigation.slice(0, -1);
      history.replaceState({ binder: true }, "", navigation.length ? `#collection/${navigation[navigation.length - 1]}` : "#home");
      searchText = "";
      render();
    }
  });

  modal.addEventListener("click", async (event) => {
    if (event.target === modal) { closeModal(); return; }
    if (event.target.closest('[data-modal-action="close"]')) { closeModal(); return; }
    const actionButton = event.target.closest("[data-collection-action]");
    if (!actionButton) return;
    const targetID = actionButton.dataset.id;
    const action = actionButton.dataset.collectionAction;
    const collection = findCollection(targetID);
    closeModal();
    if (!collection) return;
    if (action === "edit") openCollectionEditor(collection, findParent(targetID)?.id ?? null);
    if (action === "move") openMoveCollection(targetID);
    if (action === "delete") deleteCollection(targetID);
  });

  modal.addEventListener("click", (event) => {
    if (event.target === modal) closeModal();
  });

  modal.addEventListener("close", () => { modal.innerHTML = ""; });
  app.addEventListener("input", (event) => {
    if (event.target.id !== "card-search") return;
    searchText = event.target.value;
    const cursor = event.target.selectionStart;
    render();
    const replacement = document.getElementById("card-search");
    replacement?.focus();
    if (cursor !== null) replacement?.setSelectionRange(cursor, cursor);
  });

  window.addEventListener("popstate", () => {
    restoreNavigationFromURL();
    searchText = "";
    render();
  });

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    deferredInstallPrompt = event;
  });
  window.addEventListener("appinstalled", () => showToast("Binder was installed"));

  async function start() {
    renderLoading();
    state = await readPersistedState();
    if (!["system", "light", "dark"].includes(state.theme)) state.theme = "system";
    if (migrateCollectionColors(state.collections)) await persist();
    restoreNavigationFromURL();
    render();
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("./sw.js").catch(() => {});
    }
  }

  start();
})();
