function click_table_row(id){
    $('table#'+id+' > tbody > tr').click(function () {
        window.location.href = $(this).attr('url')
    });
}