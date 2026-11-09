#ifndef F_CPU
#define F_CPU 8000000UL
#endif

#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdint.h>
#include <stdlib.h>
#include <util/delay.h>

#define ASTEPTARE_MIN_MS  500U
#define ASTEPTARE_MAX_MS  8000U
#define REZULTAT_MS       3000U
#define CONFIRMARE_MS     5U
#define PUNCT_ZECIMAL     0b10000000
#define MASCA_BUTOANE     ((1 << PD2) | (1 << PD3) | (1 << PD4))

static volatile uint32_t milisecunde;
static volatile uint8_t pozitie;
static volatile uint8_t segmente_afisaj[4];

static uint8_t codifica_cifra(uint8_t cifra)
{
    switch (cifra) {
        case 0: return 0b00111111;
        case 1: return 0b00000110;
        case 2: return 0b01011011;
        case 3: return 0b01001111;
        case 4: return 0b01100110;
        case 5: return 0b01101101;
        case 6: return 0b01111101;
        case 7: return 0b00000111;
        case 8: return 0b01111111;
        case 9: return 0b01101111;
        default: return 0;
    }
}

static void display(uint8_t digit, uint8_t segmente)
{
    PORTC = 0;
    PORTA &= 0b11110000;

    _delay_us(94);
    PORTC = segmente;
    _delay_us(12);

    switch (digit) {
        case 0: PORTA |= (1 << PA2); break;
        case 1: PORTA |= (1 << PA1); break;
        case 2: PORTA |= (1 << PA3); break;
        case 3: PORTA |= (1 << PA0); break;
    }
}

static void init_porturi(void)
{

    uint8_t configurare = MCUCSR | (1 << JTD);
    MCUCSR = configurare;
    MCUCSR = configurare;

    PORTA = 0;
    PORTC = 0;
    DDRA = 0b11101111;
    DDRC = 0b11111111;
    DDRD &= ~MASCA_BUTOANE;
    PORTD |= MASCA_BUTOANE;
}

static void init_timer_0(void)
{
    TCCR0 = 0;
    TCNT0 = 0;
    OCR0 = 124;
    TIFR = (1 << OCF0);
    TIMSK |= (1 << OCIE0);
    TCCR0 = (1 << WGM01) | (1 << CS01) | (1 << CS00);
}

ISR(TIMER0_COMP_vect)
{
    display(pozitie, segmente_afisaj[pozitie]);
    pozitie++;
    if (pozitie == 4)
        pozitie = 0;

    milisecunde++;
}

static uint32_t citeste_milisecunde(void)
{
    uint8_t stare = SREG;
    cli();
    uint32_t timp = milisecunde;
    SREG = stare;
    return timp;
}

static uint32_t asteapta_milisecunda(uint32_t anterior)
{
    uint32_t acum;
    do {
        acum = citeste_milisecunde();
    } while (acum == anterior);
    return acum;
}

static void asteapta_interval(uint32_t inceput, uint16_t durata)
{
    while (citeste_milisecunde() - inceput < durata) {

    }
}

static uint32_t afiseaza(uint8_t a, uint8_t b, uint8_t c, uint8_t d,
                         uint8_t primul_digit)
{

    uint8_t stare = SREG;
    cli();
    segmente_afisaj[0] = a;
    segmente_afisaj[1] = b;
    segmente_afisaj[2] = c;
    segmente_afisaj[3] = d;
    pozitie = primul_digit;
    uint32_t anterior = milisecunde;
    SREG = stare;

    return asteapta_milisecunda(anterior);
}

static uint32_t masoara_reactia(uint8_t masca, uint32_t inceput)
{
    uint32_t acum = inceput;
    uint32_t prima_apasare = inceput;
    uint8_t confirmari = 0;

    if (!(PIND & masca)) {
        while (confirmari < CONFIRMARE_MS) {
            acum = asteapta_milisecunda(acum);
            if (PIND & masca)
                confirmari++;
            else
                confirmari = 0;
        }
    }

    confirmari = 0;
    for (;;) {
        acum = asteapta_milisecunda(acum);
        if (PIND & masca) {
            confirmari = 0;
        } else {
            if (confirmari == 0)
                prima_apasare = acum;
            confirmari++;
            if (confirmari == CONFIRMARE_MS)
                return prima_apasare - inceput;
        }
    }
}

static uint32_t afiseaza_rezultat(uint32_t timp_ms)
{
    if (timp_ms > 99999UL)
        timp_ms = 99999UL;

    uint8_t pozitie_punct = 0;
    if (timp_ms >= 10000UL) {
        timp_ms /= 10;
        pozitie_punct = 1;
    }

    uint16_t valoare = (uint16_t)timp_ms;
    uint8_t a = codifica_cifra(valoare / 1000);
    uint8_t b = codifica_cifra((valoare / 100) % 10);
    uint8_t c = codifica_cifra((valoare / 10) % 10);
    uint8_t d = codifica_cifra(valoare % 10);
    if (pozitie_punct == 0)
        a |= PUNCT_ZECIMAL;
    else
        b |= PUNCT_ZECIMAL;

    return afiseaza(a, b, c, d, 0);
}

int main(void)
{
    cli();
    init_porturi();
    init_timer_0();
    sei();

    for (;;) {
        uint8_t zero = codifica_cifra(0);
        uint32_t inceput = afiseaza(zero, zero, zero, zero, 0);
        uint16_t pauza = ASTEPTARE_MIN_MS
            + rand() % (ASTEPTARE_MAX_MS - ASTEPTARE_MIN_MS + 1);
        asteapta_interval(inceput, pauza);

        uint8_t cifra = 1 + rand() % 3;
        uint8_t masca = 1 << (PD2 + cifra - 1);
        inceput = afiseaza(0, 0, 0, codifica_cifra(cifra), 3);
        uint32_t rezultat = masoara_reactia(masca, inceput);
        uint32_t afisare = afiseaza_rezultat(rezultat);

        srand((unsigned int)rand() ^ (unsigned int)rezultat);
        asteapta_interval(afisare, REZULTAT_MS);
    }
}
