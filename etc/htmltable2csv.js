//
// function to convert a HTML table to a CSV file on the fly.
// The 'tabletoCSV function should be put with a onclick commandin a button
//
// Modified to accept the table ID
//

function tableToCSV( id, fileName ) {
    // Variable to store the final csv data
    var csv_data = [];
    // Get each row data
    //var table = document.getElementById(id);
    var table = id.parentNode;
    console.log('table= ' + table);
    //var rows = document.getElementsByTagName('tr');
    var rows = table.querySelectorAll('tr');
    for (let i = 0; i < rows.length; i++) {
	// Get each column data
	let cols = rows[i].querySelectorAll('td,th');
	// Stores each csv row data
	var csvrow = [];
	for (let j = 0; j < cols.length; j++) {
	    // Get the text data of each cell
	    // of a row and push it to csvrow
	    csvrow.push(cols[j].innerHTML);
	}
	// Combine each column value with comma
	csv_data.push(csvrow.join(","));
    }
    // Combine each row data with new line character
    csv_data = csv_data.join('\n');
    // Call this function to download csv file
    downloadCSVFile(csv_data, fileName);
}

function downloadCSVFile(csv_data, fileName) {
    // Create CSV file object and feed
    // our csv_data into it
    CSVFile = new Blob([csv_data], {type: "text/csv"});
    // Create to temporary link to initiate
    // download process
    var temp_link = document.createElement('a');
    // Download csv file
    temp_link.download = fileName;
    var url = window.URL.createObjectURL(CSVFile);
    temp_link.href = url;
    // This link should not be displayed
    temp_link.style.display = "none";
    document.body.appendChild(temp_link);
    // Automatically click the link to
    // trigger download
    temp_link.click();
    document.body.removeChild(temp_link);
}

