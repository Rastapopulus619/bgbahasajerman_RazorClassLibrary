window.scrollElementIntoView = (element, index) => {
    console.log(`JS: Scrolling to index ${index}`);
    const li = element.children[index];
    if (li) li.scrollIntoView({ behavior: 'auto', block: 'nearest' });
};